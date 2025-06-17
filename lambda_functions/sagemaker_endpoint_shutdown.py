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
IDLE_THRESHOLD_INVOCATIONS = int(os.environ.get('IDLE_THRESHOLD_INVOCATIONS', '5'))  # Default to 5 invocations
IDLE_DURATION_MINUTES = int(os.environ.get('IDLE_DURATION_MINUTES', '60'))  # Default to 60 minutes
ENDPOINT_NAME_PREFIX = os.environ.get('ENDPOINT_NAME_PREFIX', '')  # Default to all endpoints
EXCLUDE_ENDPOINT_TAG = os.environ.get('EXCLUDE_ENDPOINT_TAG', 'AutoShutdownExclude')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')

def lambda_handler(event, context):
    """
    Monitors SageMaker endpoints and shuts down idle endpoints.
    
    Parameters:
    event (dict): Event data, typically triggered by CloudWatch Events
    context (object): Lambda context
    
    Returns:
    dict: Response containing the shutdown details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize AWS clients
        sagemaker_client = boto3.client('sagemaker')
        cloudwatch_client = boto3.client('cloudwatch')
        dynamodb = boto3.resource('dynamodb')
        
        # Get all active endpoints
        endpoints = get_active_endpoints(sagemaker_client)
        logger.info(f"Found {len(endpoints)} active endpoints")
        
        # Check each endpoint for idleness
        shutdown_results = []
        for endpoint in endpoints:
            endpoint_name = endpoint['EndpointName']
            
            # Skip endpoints with exclude tag
            if has_exclude_tag(sagemaker_client, endpoint_name):
                logger.info(f"Skipping endpoint {endpoint_name} due to exclude tag")
                continue
            
            # Check if endpoint is idle
            if is_endpoint_idle(cloudwatch_client, endpoint_name):
                logger.info(f"Endpoint {endpoint_name} is idle, checking if it can be shut down")
                
                # Check if there are any active jobs using this endpoint
                if has_active_jobs(dynamodb.Table(DYNAMODB_TABLE), endpoint_name):
                    logger.info(f"Endpoint {endpoint_name} has active jobs, not shutting down")
                    continue
                
                logger.info(f"Endpoint {endpoint_name} is idle and has no active jobs, shutting down")
                
                # Shutdown the endpoint
                try:
                    sagemaker_client.delete_endpoint(EndpointName=endpoint_name)
                    shutdown_results.append({
                        'endpoint_name': endpoint_name,
                        'status': 'shutdown_initiated'
                    })
                except Exception as e:
                    logger.error(f"Error shutting down endpoint {endpoint_name}: {e}")
                    shutdown_results.append({
                        'endpoint_name': endpoint_name,
                        'status': 'error',
                        'error': str(e)
                    })
            else:
                logger.info(f"Endpoint {endpoint_name} is not idle")
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Checked {len(endpoints)} endpoints, shut down {len(shutdown_results)} idle endpoints",
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

def get_active_endpoints(sagemaker_client):
    """
    Gets a list of active SageMaker endpoints.
    
    Parameters:
    sagemaker_client (boto3.client): SageMaker client
    
    Returns:
    list: List of active SageMaker endpoints
    """
    endpoints = []
    next_token = None
    
    while True:
        if next_token:
            response = sagemaker_client.list_endpoints(NextToken=next_token)
        else:
            response = sagemaker_client.list_endpoints()
        
        for endpoint in response['Endpoints']:
            # Filter by status and name prefix if specified
            if endpoint['EndpointStatus'] == 'InService' and (not ENDPOINT_NAME_PREFIX or endpoint['EndpointName'].startswith(ENDPOINT_NAME_PREFIX)):
                endpoints.append(endpoint)
        
        next_token = response.get('NextToken')
        if not next_token:
            break
    
    return endpoints

def has_exclude_tag(sagemaker_client, endpoint_name):
    """
    Checks if an endpoint has the exclude tag.
    
    Parameters:
    sagemaker_client (boto3.client): SageMaker client
    endpoint_name (str): SageMaker endpoint name
    
    Returns:
    bool: True if the endpoint has the exclude tag, False otherwise
    """
    try:
        response = sagemaker_client.list_tags(
            ResourceArn=f"arn:aws:sagemaker:{os.environ.get('AWS_REGION')}:{os.environ.get('AWS_ACCOUNT_ID')}:endpoint/{endpoint_name}"
        )
        
        for tag in response.get('Tags', []):
            if tag.get('Key') == EXCLUDE_ENDPOINT_TAG and tag.get('Value') == 'true':
                return True
        
        return False
    except Exception as e:
        logger.error(f"Error checking tags for endpoint {endpoint_name}: {e}")
        return False  # Assume no exclude tag if there's an error

def is_endpoint_idle(cloudwatch_client, endpoint_name):
    """
    Checks if a SageMaker endpoint is idle based on invocation count.
    
    Parameters:
    cloudwatch_client (boto3.client): CloudWatch client
    endpoint_name (str): SageMaker endpoint name
    
    Returns:
    bool: True if the endpoint is idle, False otherwise
    """
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=IDLE_DURATION_MINUTES)
    
    # Get invocation metrics
    response = cloudwatch_client.get_metric_statistics(
        Namespace='AWS/SageMaker',
        MetricName='Invocations',
        Dimensions=[
            {
                'Name': 'EndpointName',
                'Value': endpoint_name
            }
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,  # 5-minute periods
        Statistics=['Sum']
    )
    
    datapoints = response.get('Datapoints', [])
    
    # If no datapoints, consider the endpoint as idle
    if not datapoints:
        logger.warning(f"No invocation data for endpoint {endpoint_name}")
        return True
    
    # Calculate total invocations
    total_invocations = sum(datapoint.get('Sum', 0) for datapoint in datapoints)
    
    # Check if total invocations are below the threshold
    return total_invocations < IDLE_THRESHOLD_INVOCATIONS

def has_active_jobs(table, endpoint_name):
    """
    Checks if there are any active jobs using the specified endpoint.
    
    Parameters:
    table (DynamoDB.Table): DynamoDB table object
    endpoint_name (str): SageMaker endpoint name
    
    Returns:
    bool: True if there are active jobs, False otherwise
    """
    if not DYNAMODB_TABLE:
        logger.warning("No DynamoDB table specified, assuming no active jobs")
        return False
    
    try:
        # Query DynamoDB for active jobs using this endpoint
        response = table.scan(
            FilterExpression="(#status = :processing OR #status = :initiated) AND contains(#endpoint, :endpoint_name)",
            ExpressionAttributeNames={
                "#status": "Status",
                "#endpoint": "Endpoints"
            },
            ExpressionAttributeValues={
                ":processing": "PROCESSING",
                ":initiated": "INITIATED",
                ":endpoint_name": endpoint_name
            }
        )
        
        return len(response.get('Items', [])) > 0
    except Exception as e:
        logger.error(f"Error checking active jobs for endpoint {endpoint_name}: {e}")
        return True  # Assume active jobs if there's an error, to be safe