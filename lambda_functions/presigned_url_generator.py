import json
import boto3
import os
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get environment variables
SOURCE_BUCKET = os.environ.get('SOURCE_BUCKET')
URL_EXPIRATION = int(os.environ.get('URL_EXPIRATION', '3600'))  # Default to 1 hour

def lambda_handler(event, context):
    """
    Generate a presigned URL for uploading a file to S3.
    
    Parameters:
    event (dict): Lambda event data
    context (object): Lambda context
    
    Returns:
    dict: Response containing the presigned URL or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract parameters from the event
        if 'queryStringParameters' in event and event['queryStringParameters']:
            params = event['queryStringParameters']
            file_name = params.get('fileName')
            content_type = params.get('contentType', 'application/octet-stream')
            expiration = int(params.get('expiration', URL_EXPIRATION))
        elif 'body' in event and event['body']:
            body = json.loads(event['body'])
            file_name = body.get('fileName')
            content_type = body.get('contentType', 'application/octet-stream')
            expiration = int(body.get('expiration', URL_EXPIRATION))
        else:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required parameters'
                })
            }
        
        # Validate parameters
        if not file_name:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'fileName is required'
                })
            }
        
        # Ensure expiration is within allowed limits (5 min to 7 days)
        if expiration < 300 or expiration > 604800:
            expiration = URL_EXPIRATION
        
        # Generate the presigned URL
        s3_client = boto3.client('s3')
        object_key = f"uploads/{file_name}"
        
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': SOURCE_BUCKET,
                'Key': object_key,
                'ContentType': content_type
            },
            ExpiresIn=expiration
        )
        
        logger.info(f"Generated presigned URL for {object_key} with expiration {expiration} seconds")
        
        # Return the presigned URL
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'url': presigned_url,
                'key': object_key,
                'bucket': SOURCE_BUCKET,
                'expiresIn': expiration
            })
        }
        
    except ClientError as e:
        logger.error(f"Error generating presigned URL: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f"Error generating presigned URL: {str(e)}"
            })
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f"Unexpected error: {str(e)}"
            })
        }