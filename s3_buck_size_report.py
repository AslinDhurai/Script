import boto3
import csv
import os
import datetime
import json
from collections import defaultdict
from botocore.exceptions import ClientError
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.mime.text import MIMEText

AWS_REGION = "ap-south-1"
VERIFIED_EMAIL = "dharshanasudharsanan@gmail.com"
ATTACHMENT = "/tmp/s3_report_with_cost.csv"
TODAY = datetime.datetime.now().strftime("%Y-%m-%d")
SUBJECT = f"Daily S3 Bucket Usage Report - {TODAY}"

def get_s3_pricing():
    pricing_client = boto3.client('pricing', region_name='us-east-1')
    storage_classes = {
        "STANDARD": "Standard",
        "STANDARD_IA": "Standard - Infrequent Access",
        "ONEZONE_IA": "One Zone - Infrequent Access",
        "GLACIER": "Glacier",
        "DEEP_ARCHIVE": "Glacier Deep Archive"
    }
    pricing = {}

    for key, display_name in storage_classes.items():
        try:
            response = pricing_client.get_products(
                ServiceCode='AmazonS3',
                Filters=[
                    {'Type': 'TERM_MATCH', 'Field': 'storageClass', 'Value': display_name},
                    {'Type': 'TERM_MATCH', 'Field': 'location', 'Value': 'Asia Pacific (Mumbai)'},
                    {'Type': 'TERM_MATCH', 'Field': 'usagetype', 'Value': 'TimedStorage-ByteHrs'},
                ],
                MaxResults=1
            )

            if not response['PriceList']:
                continue

            product = json.loads(response['PriceList'][0])
            terms = list(product['terms']['OnDemand'].values())[0]
            price_dimensions = list(terms['priceDimensions'].values())[0]
            usd_price = float(price_dimensions['pricePerUnit']['USD'])
            monthly_price = usd_price * 24 * 30
            pricing[key] = round(monthly_price * 1024, 5)
        except Exception as e:
            print(f"Failed to fetch pricing for {display_name}: {e}")

    return pricing

def lambda_handler(event, context):
    STORAGE_PRICING = get_s3_pricing()
    s3 = boto3.client('s3', region_name=AWS_REGION)

    try:
        buckets = s3.list_buckets()['Buckets']
    except ClientError as e:
        print("Failed to list buckets:", e)
        return {'statusCode': 500, 'body': 'Failed to list buckets'}

    with open(ATTACHMENT, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['Bucket Name', 'Storage Class', 'Size (Bytes)', 'Size (GB)', 'Estimated Monthly Cost ($)'])

        for bucket in buckets:
            bucket_name = bucket['Name']
            storage_totals = defaultdict(int)
            paginator = s3.get_paginator('list_objects_v2')

            try:
                for page in paginator.paginate(Bucket=bucket_name):
                    for obj in page.get('Contents', []):
                        size = obj['Size']
                        storage_class = obj.get('StorageClass', 'STANDARD')
                        storage_totals[storage_class] += size
            except ClientError as e:
                print(f"Skipping {bucket_name} due to error: {e}")
                continue

            for storage_class, total_size_bytes in storage_totals.items():
                size_gb = total_size_bytes / (1024 ** 3)
                cost_per_gb = STORAGE_PRICING.get(storage_class, STORAGE_PRICING.get('STANDARD', 0.023))
                estimated_cost = round(size_gb * cost_per_gb, 5)
                writer.writerow([bucket_name, storage_class, total_size_bytes, round(size_gb, 2), estimated_cost])

    print(f"Report generated: {ATTACHMENT}")

    msg = MIMEMultipart()
    msg['Subject'] = SUBJECT
    msg['From'] = VERIFIED_EMAIL
    msg['To'] = VERIFIED_EMAIL

    body_text = (
        f"Hi,\n\n"
        f"Attached is the S3 usage and estimated cost report for {TODAY}.\n\n"
        "Regards,\nS3 Reporter Script"
    )
    msg.attach(MIMEText(body_text, 'plain'))

    with open(ATTACHMENT, 'rb') as file:
        part = MIMEApplication(file.read())
        part.add_header('Content-Disposition', 'attachment', filename=os.path.basename(ATTACHMENT))
        msg.attach(part)

    try:
        ses = boto3.client('ses', region_name=AWS_REGION)
        response = ses.send_raw_email(
            Source=VERIFIED_EMAIL,
            Destinations=[VERIFIED_EMAIL],
            RawMessage={'Data': msg.as_string()}
        )
        print("Email sent! Message ID:", response['MessageId'])
        return {'statusCode': 200, 'body': 'Email sent successfully'}
    except ClientError as e:
        print("Failed to send email:", e.response['Error']['Message'])
        return {'statusCode': 500, 'body': 'Failed to send email'}
