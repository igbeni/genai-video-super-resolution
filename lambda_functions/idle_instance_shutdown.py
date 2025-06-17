import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get environment variables
IDLE_THRESHOLD_PERCENT = float(os.environ.get('IDLE_THRESHOLD_PERCENT', '10.0'))  # Default to 10% CPU utilization
IDLE_DURATION_MINUTES = int(os.environ.get('IDLE_DURATION_MINUTES', '30'))  # Default to 30 minutes
INSTANCE_TAG_KEY = os.environ.get('INSTANCE_TAG_KEY', 'Name')
INSTANCE_TAG_VALUE = os.environ.get('INSTANCE_TAG_VALUE', '*')  # Default to all instances
EXCLUDE_TAG_KEY = os.environ.get('EXCLUDE_TAG_KEY', 'AutoShutdownExclude')
EXCLUDE_TAG_VALUE = os.environ.get('EXCLUDE_TAG_VALUE', 'true')

def lambda_handler(event, context):
    """
    Monitors EC2 instances and shuts down idle instances.
    
    Parameters:
    event (dict): Event data, typically triggered by CloudWatch Events
    context (object): Lambda context
    
    Returns:
    dict: Response containing the shutdown details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize AWS clients
        ec2_client = boto3.client('ec2')
        cloudwatch_client = boto3.client('cloudwatch')
        
        # Get all running instances
        instances = get_running_instances(ec2_client)
        logger.info(f"Found {len(instances)} running instances")
        
        # Check each instance for idleness
        shutdown_results = []
        for instance in instances:
            instance_id = instance['InstanceId']
            
            # Skip instances with exclude tag
            if has_exclude_tag(instance):
                logger.info(f"Skipping instance {instance_id} due to exclude tag")
                continue
            
            # Check if instance is idle
            if is_instance_idle(cloudwatch_client, instance_id):
                logger.info(f"Instance {instance_id} is idle, shutting down")
                
                # Shutdown the instance
                try:
                    ec2_client.stop_instances(InstanceIds=[instance_id])
                    shutdown_results.append({
                        'instance_id': instance_id,
                        'status': 'shutdown_initiated'
                    })
                except Exception as e:
                    logger.error(f"Error shutting down instance {instance_id}: {e}")
                    shutdown_results.append({
                        'instance_id': instance_id,
                        'status': 'error',
                        'error': str(e)
                    })
            else:
                logger.info(f"Instance {instance_id} is not idle")
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Checked {len(instances)} instances, shut down {len(shutdown_results)} idle instances",
                'results': shutdown_results
            })
        }
        
    except ClientError as e:
        logger.error(f"AWS service error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f"AWS service error: {str(e)}"
            })
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f"Unexpected error: {str(e)}"
            })
        }

def get_running_instances(ec2_client):
    """
    Gets a list of running EC2 instances.
    
    Parameters:
    ec2_client (boto3.client): EC2 client
    
    Returns:
    list: List of running EC2 instances
    """
    filters = [
        {
            'Name': 'instance-state-name',
            'Values': ['running']
        }
    ]
    
    # Add tag filter if specified
    if INSTANCE_TAG_VALUE != '*':
        filters.append({
            'Name': f'tag:{INSTANCE_TAG_KEY}',
            'Values': [INSTANCE_TAG_VALUE]
        })
    
    response = ec2_client.describe_instances(Filters=filters)
    
    instances = []
    for reservation in response.get('Reservations', []):
        for instance in reservation.get('Instances', []):
            instances.append(instance)
    
    return instances

def has_exclude_tag(instance):
    """
    Checks if an instance has the exclude tag.
    
    Parameters:
    instance (dict): EC2 instance details
    
    Returns:
    bool: True if the instance has the exclude tag, False otherwise
    """
    tags = instance.get('Tags', [])
    for tag in tags:
        if tag.get('Key') == EXCLUDE_TAG_KEY and tag.get('Value') == EXCLUDE_TAG_VALUE:
            return True
    return False

def is_instance_idle(cloudwatch_client, instance_id):
    """
    Checks if an EC2 instance is idle based on CPU utilization.
    
    Parameters:
    cloudwatch_client (boto3.client): CloudWatch client
    instance_id (str): EC2 instance ID
    
    Returns:
    bool: True if the instance is idle, False otherwise
    """
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=IDLE_DURATION_MINUTES)
    
    # Get CPU utilization metrics
    response = cloudwatch_client.get_metric_statistics(
        Namespace='AWS/EC2',
        MetricName='CPUUtilization',
        Dimensions=[
            {
                'Name': 'InstanceId',
                'Value': instance_id
            }
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,  # 5-minute periods
        Statistics=['Average']
    )
    
    datapoints = response.get('Datapoints', [])
    
    # If no datapoints, consider the instance as not idle (to be safe)
    if not datapoints:
        logger.warning(f"No CPU utilization data for instance {instance_id}")
        return False
    
    # Check if all datapoints are below the threshold
    for datapoint in datapoints:
        if datapoint.get('Average', 100) > IDLE_THRESHOLD_PERCENT:
            return False
    
    # All datapoints are below the threshold, instance is idle
    return True