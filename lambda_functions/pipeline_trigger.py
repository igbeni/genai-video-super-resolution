import json
import boto3
import os
import uuid
import logging
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get environment variables
SOURCE_BUCKET = os.environ.get('SOURCE_BUCKET')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
FINAL_BUCKET = os.environ.get('FINAL_BUCKET')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
EXTRACT_FRAMES_SNS = os.environ.get('EXTRACT_FRAMES_SNS')

def lambda_handler(event, context):
    """
    Trigger the video super-resolution pipeline when a new video is uploaded to S3.
    
    Parameters:
    event (dict): S3 event notification
    context (object): Lambda context
    
    Returns:
    dict: Response containing the job details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract S3 event details
        s3_event = event['Records'][0]['s3']
        bucket_name = s3_event['bucket']['name']
        object_key = s3_event['object']['key']
        
        # Validate that this is a video file (simple check based on extension)
        valid_extensions = ['.mp4', '.avi', '.mov', '.mkv']
        if not any(object_key.lower().endswith(ext) for ext in valid_extensions):
            logger.warning(f"Ignoring non-video file: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f"Ignoring non-video file: {object_key}"
                })
            }
        
        # Generate a unique job ID
        job_id = str(uuid.uuid4())
        
        # Get video metadata
        s3_client = boto3.client('s3')
        response = s3_client.head_object(Bucket=bucket_name, Key=object_key)
        content_length = response.get('ContentLength', 0)
        content_type = response.get('ContentType', 'application/octet-stream')
        
        # Extract video name from the object key
        video_name = os.path.basename(object_key)
        
        # Create job metadata
        timestamp = datetime.utcnow().isoformat()
        job_metadata = {
            'JobId': job_id,
            'VideoName': video_name,
            'SourceBucket': bucket_name,
            'SourceKey': object_key,
            'ProcessedBucket': PROCESSED_BUCKET,
            'FinalBucket': FINAL_BUCKET,
            'ContentLength': content_length,
            'ContentType': content_type,
            'Status': 'INITIATED',
            'CreatedAt': timestamp,
            'UpdatedAt': timestamp,
            'Frames': {
                'Total': 0,
                'Extracted': 0,
                'Processed': 0
            }
        }
        
        # Store job metadata in DynamoDB
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.put_item(Item=job_metadata)
        
        logger.info(f"Created job metadata in DynamoDB: {job_id}")
        
        # Publish message to SNS to start frame extraction
        sns_client = boto3.client('sns')
        sns_message = {
            'jobId': job_id,
            'videoName': video_name,
            'sourceBucket': bucket_name,
            'sourceKey': object_key
        }
        
        sns_client.publish(
            TopicArn=EXTRACT_FRAMES_SNS,
            Message=json.dumps(sns_message),
            Subject=f"Extract Frames: {video_name}"
        )
        
        logger.info(f"Published message to SNS topic: {EXTRACT_FRAMES_SNS}")
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'jobId': job_id,
                'videoName': video_name,
                'status': 'INITIATED',
                'message': 'Video processing pipeline initiated successfully'
            })
        }
        
    except KeyError as e:
        logger.error(f"Missing key in event: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': f"Missing key in event: {str(e)}"
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