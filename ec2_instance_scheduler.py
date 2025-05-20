Lambda Function for stopping instances with tag"env=dev"
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    
    try:
        # Describe EC2 instances filtered by 'env=dev'
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:env', 'Values': ['dev']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        # Collect instance IDs of instances to stop
        instance_ids = [i['InstanceId']
                        for r in response['Reservations']
                        for i in r['Instances']]

        if not instance_ids:
            logger.info("No instances to stop.")
            return {
                'statusCode': 200,
                'body': 'No instances found to stop.'
            }

        # Stop the instances
        logger.info(f"Stopping instances: {instance_ids}")
        ec2.stop_instances(InstanceIds=instance_ids)
        
        return {
            'statusCode': 200,
            'body': f"Stopped instances: {instance_ids}"
        }

    except Exception as e:
        logger.error(f"Error stopping instances: {str(e)}")
        raise e


           
    
