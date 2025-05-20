import boto3
import json
import datetime
import os
import urllib3
import time
from datetime import datetime, timedelta

# Initialize AWS clients
ce_client = boto3.client('ce')  # Cost Explorer
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
dynamodb = boto3.client('dynamodb')

# Slack webhook URL should be stored in environment variable
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
http = urllib3.PoolManager()

# DynamoDB table for tracking approval status
APPROVAL_TABLE = 'ResourceOptimizationApprovals'

def create_approval_table_if_not_exists():
    try:
        dynamodb.create_table(
            TableName=APPROVAL_TABLE,
            KeySchema=[{'AttributeName': 'approval_id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'approval_id', 'AttributeType': 'S'}],
            ProvisionedThroughput={'ReadCapacityUnits': 5, 'WriteCapacityUnits': 5}
        )
        print(f"Created table {APPROVAL_TABLE}")
    except dynamodb.exceptions.ResourceInUseException:
        pass

def store_pending_approval(approval_id, recommendations, idle_resources):
    dynamodb.put_item(
        TableName=APPROVAL_TABLE,
        Item={
            'approval_id': {'S': approval_id},
            'recommendations': {'S': json.dumps(recommendations)},
            'idle_resources': {'S': json.dumps(idle_resources)},
            'status': {'S': 'pending'},
            'timestamp': {'N': str(int(time.time()))}
        }
    )

def get_pending_approval(approval_id):
    try:
        response = dynamodb.get_item(
            TableName=APPROVAL_TABLE,
            Key={'approval_id': {'S': approval_id}}
        )
        if 'Item' in response:
            return {
                'recommendations': json.loads(response['Item']['recommendations']['S']),
                'idle_resources': json.loads(response['Item']['idle_resources']['S']),
                'status': response['Item']['status']['S']
            }
    except Exception as e:
        print(f"Error getting approval: {str(e)}")
    return None

def update_approval_status(approval_id, status):
    dynamodb.update_item(
        TableName=APPROVAL_TABLE,
        Key={'approval_id': {'S': approval_id}},
        UpdateExpression='SET #s = :s',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={':s': {'S': status}}
    )

def get_rightsizing_recommendations():
    recommendations = []
    try:
        response = ce_client.get_rightsizing_recommendation(
            Service='AmazonEC2',
            Configuration={
                'BenefitsConsidered': True,
                'RecommendationTarget': 'SAME_INSTANCE_FAMILY',
            }
        )
        if response['RightsizingRecommendations']:
            recommendations.extend(response['RightsizingRecommendations'])
    except Exception as e:
        print(f"Error getting rightsizing recommendations: {str(e)}")
    return recommendations

def find_idle_resources():
    idle_resources = {'ec2': [], 'rds': []}
    regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]
    
    for region in regions:
        ec2 = boto3.client('ec2', region_name=region)
        rds = boto3.client('rds', region_name=region)
        cloudwatch = boto3.client('cloudwatch', region_name=region)
        
        # Find idle EC2 instances
        ec2_instances = ec2.describe_instances()
        for reservation in ec2_instances['Reservations']:
            for instance in reservation['Instances']:
                if instance['State']['Name'] == 'running':
                    metrics = cloudwatch.get_metric_statistics(
                        Namespace='AWS/EC2',
                        MetricName='CPUUtilization',
                        Dimensions=[{'Name': 'InstanceId', 'Value': instance['InstanceId']}],
                        StartTime=datetime.now() - timedelta(days=7),
                        EndTime=datetime.now(),
                        Period=3600,
                        Statistics=['Average']
                    )
                    if metrics['Datapoints']:
                        avg_cpu = sum(dp['Average'] for dp in metrics['Datapoints']) / len(metrics['Datapoints'])
                        if avg_cpu < 8:
                            idle_resources['ec2'].append({
                                'region': region,
                                'instance_id': instance['InstanceId'],
                                'avg_cpu': avg_cpu
                            })
        
        # Find idle RDS instances
        rds_instances = rds.describe_db_instances()
        for instance in rds_instances['DBInstances']:
            metrics = cloudwatch.get_metric_statistics(
                Namespace='AWS/RDS',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'DBInstanceIdentifier', 'Value': instance['DBInstanceIdentifier']}],
                StartTime=datetime.now() - timedelta(days=7),
                EndTime=datetime.now(),
                Period=3600,
                Statistics=['Average']
            )
            if metrics['Datapoints']:
                avg_cpu = sum(dp['Average'] for dp in metrics['Datapoints']) / len(metrics['Datapoints'])
                if avg_cpu < 8:
                    idle_resources['rds'].append({
                        'region': region,
                        'instance_id': instance['DBInstanceIdentifier'],
                        'avg_cpu': avg_cpu
                    })
    
    return idle_resources

def send_slack_notification(recommendations, idle_resources, approval_id):
    message = "*AWS Resource Optimization Report*\n\n"
    
    if recommendations:
        message += "*Rightsizing Recommendations:*\n"
        for rec in recommendations:
            message += f"• Instance {rec['CurrentInstance']['InstanceId']}: "
            message += f"Recommend changing from {rec['CurrentInstance']['InstanceType']} to {rec['TargetInstance']['InstanceType']}\n"
            message += f"  Estimated monthly savings: ${rec['ProjectedMonthlySavings']['Amount']:.2f}\n"
    else:
        message += "*No rightsizing recommendations found.*\n"
    
    if idle_resources['ec2'] or idle_resources['rds']:
        message += "\n*Idle Resources Found:*\n"
        
        if idle_resources['ec2']:
            message += "*EC2 Instances:*\n"
            for instance in idle_resources['ec2']:
                message += f"• Region: {instance['region']}, Instance: {instance['instance_id']}, Avg CPU: {instance['avg_cpu']:.2f}%\n"
        
        if idle_resources['rds']:
            message += "*RDS Instances:*\n"
            for instance in idle_resources['rds']:
                message += f"• Region: {instance['region']}, Instance: {instance['instance_id']}, Avg CPU: {instance['avg_cpu']:.2f}%\n"
    else:
        message += "\n*No idle resources found.*\n"
    
    message += f"\nPlease respond with 'approve {approval_id}' to execute the recommended changes, or 'reject {approval_id}' to cancel."
    
    try:
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=json.dumps({'text': message}),
            headers={'Content-Type': 'application/json'}
        )
        return response.status
    except Exception as e:
        print(f"Error sending Slack message: {str(e)}")
        return None

def execute_changes(recommendations, idle_resources):
    for rec in recommendations:
        instance_id = rec['CurrentInstance']['InstanceId']
        new_type = rec['TargetInstance']['InstanceType']
        region = rec['CurrentInstance']['Region']
        
        ec2 = boto3.client('ec2', region_name=region)
        try:
            ec2.stop_instances(InstanceIds=[instance_id])
            waiter = ec2.get_waiter('instance_stopped')
            waiter.wait(InstanceIds=[instance_id])
            
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                InstanceType={'Value': new_type}
            )
            
            ec2.start_instances(InstanceIds=[instance_id])
            print(f"Successfully resized instance {instance_id} to {new_type}")
        except Exception as e:
            print(f"Error modifying instance {instance_id}: {str(e)}")
    
    for instance in idle_resources['ec2']:
        ec2 = boto3.client('ec2', region_name=instance['region'])
        try:
            ec2.terminate_instances(InstanceIds=[instance['instance_id']])
            print(f"Successfully terminated EC2 instance {instance['instance_id']}")
        except Exception as e:
            print(f"Error terminating EC2 instance {instance['instance_id']}: {str(e)}")
    
    for instance in idle_resources['rds']:
        rds = boto3.client('rds', region_name=instance['region'])
        try:
            rds.delete_db_instance(
                DBInstanceIdentifier=instance['instance_id'],
                SkipFinalSnapshot=True
            )
            print(f"Successfully initiated deletion of RDS instance {instance['instance_id']}")
        except Exception as e:
            print(f"Error deleting RDS instance {instance['instance_id']}: {str(e)}")

def lambda_handler(event, context):
    try:
        # Ensure approval table exists
        create_approval_table_if_not_exists()
        
        # Check if this is an approval response
        if event.get('body'):
            body = json.loads(event['body'])
            text = body.get('text', '').strip().lower()
            
            # Look for commands starting with /optimize
            if text.startswith('/optimize'):
                command_parts = text.split(' ', 2)  # Split the command by space into parts
                
                # Ensure we have at least 3 parts (command, action, approval_id)
                if len(command_parts) >= 3:
                    action = command_parts[1]  # 'approve' or 'reject'
                    approval_id = command_parts[2]  # Dynamic approval_id

                    approval = get_pending_approval(approval_id)
                    
                    if approval and approval['status'] == 'pending':
                        if action == 'approve':
                            # Execute the recommended changes if approved
                            execute_changes(approval['recommendations'], approval['idle_resources'])
                            update_approval_status(approval_id, 'approved')
                            return {
                                'statusCode': 200,
                                'body': json.dumps(f'Changes executed successfully for approval ID: {approval_id}')
                            }
                        elif action == 'reject':
                            update_approval_status(approval_id, 'rejected')
                            return {
                                'statusCode': 200,
                                'body': json.dumps(f'Changes rejected for approval ID: {approval_id}')
                            }
            
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid approval command format')
            }
        
        # Generate new recommendations if the command wasn't an approval
        recommendations = get_rightsizing_recommendations()
        idle_resources = find_idle_resources()
        
        # Generate unique approval ID and store pending approval
        approval_id = datetime.now().strftime('%Y%m%d%H%M%S')
        store_pending_approval(approval_id, recommendations, idle_resources)
        
        # Send Slack notification
        slack_status = send_slack_notification(recommendations, idle_resources, approval_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Resource optimization check completed',
                'slack_status': slack_status,
                'approval_id': approval_id,
                'recommendations_count': len(recommendations),
                'idle_resources_count': len(idle_resources['ec2']) + len(idle_resources['rds'])
            })
        }
    
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
