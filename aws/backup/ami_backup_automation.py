import boto3
import datetime

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    today = datetime.datetime.now().strftime('%Y-%m-%d')
    
    instances = ec2.describe_instances(Filters=[{
        'Name': 'tag:Backup',
        'Values': ['true']
    }])

    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            name = f"Backup-{instance_id}-{today}"
            print(f"Creating AMI for instance {instance_id}")
            response = ec2.create_image(
                InstanceId=instance_id,
                Name=name,
                NoReboot=True
            )
            ec2.create_tags(Resources=[response['ImageId']], Tags=[
                {'Key': 'CreatedOn', 'Value': today}
            ])

    images = ec2.describe_images(Owners=['self'])['Images']
    cutoff = datetime.datetime.now() - datetime.timedelta(days=30)

    for image in images:
        image_id = image['ImageId']
        tags = {tag['Key']: tag['Value'] for tag in image.get('Tags', [])}
        if 'keep-forever' in tags.values():
            continue
        created_on = datetime.datetime.strptime(image['CreationDate'], '%Y-%m-%dT%H:%M:%S.%fZ')
        if created_on < cutoff:
            print(f"Deregistering AMI: {image_id}")
            ec2.deregister_image(ImageId=image_id)
            for mapping in image.get('BlockDeviceMappings', []):
                if 'Ebs' in mapping:
                    snapshot_id = mapping['Ebs']['SnapshotId']
                    try:
                        ec2.delete_snapshot(SnapshotId=snapshot_id)
                        print(f"Deleted snapshot {snapshot_id}")
                    except Exception as e:
                        print(f"Error deleting snapshot {snapshot_id}: {e}")
