import json
import boto3
import os
import logging
import tempfile
import gzip
import shutil
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get environment variables
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
COMPRESSION_AGE_DAYS = int(os.environ.get('COMPRESSION_AGE_DAYS', '3'))  # Default to 3 days
ENABLE_COMPRESSION = os.environ.get('ENABLE_COMPRESSION', 'true').lower() == 'true'

def lambda_handler(event, context):
    """
    Compresses intermediate files in the processed frames bucket to optimize storage costs.
    
    Parameters:
    event (dict): Event data, can be triggered by CloudWatch Events or SNS
    context (object): Lambda context
    
    Returns:
    dict: Response containing the compression details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    if not ENABLE_COMPRESSION:
        logger.info("Compression is disabled. Exiting.")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Compression is disabled',
                'compressed_count': 0
            })
        }
    
    try:
        # Initialize AWS clients
        s3_client = boto3.client('s3')
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Get completed jobs from DynamoDB
        completed_jobs = get_completed_jobs(table)
        logger.info(f"Found {len(completed_jobs)} completed jobs eligible for compression")
        
        # Compress intermediate files for completed jobs
        compression_results = compress_intermediate_files(s3_client, completed_jobs)
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Intermediate file compression completed successfully',
                'results': compression_results
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

def get_completed_jobs(table):
    """
    Gets a list of completed jobs from DynamoDB that are eligible for compression.
    
    Parameters:
    table (DynamoDB.Table): DynamoDB table object
    
    Returns:
    list: List of completed job details
    """
    # Query DynamoDB for completed jobs
    cutoff_date = (datetime.utcnow() - timedelta(days=COMPRESSION_AGE_DAYS)).isoformat()
    
    response = table.scan(
        FilterExpression="(#status = :completed) AND (#updated_at < :cutoff_date)",
        ExpressionAttributeNames={
            "#status": "Status",
            "#updated_at": "UpdatedAt"
        },
        ExpressionAttributeValues={
            ":completed": "COMPLETED",
            ":cutoff_date": cutoff_date
        }
    )
    
    return response.get('Items', [])

def compress_intermediate_files(s3_client, completed_jobs):
    """
    Compresses intermediate files for completed jobs.
    
    Parameters:
    s3_client (boto3.client): S3 client
    completed_jobs (list): List of completed job details
    
    Returns:
    dict: Compression results
    """
    results = {}
    
    for job in completed_jobs:
        job_id = job['JobId']
        
        # List all objects for this job
        objects_to_compress = []
        paginator = s3_client.get_paginator('list_objects_v2')
        
        try:
            for page in paginator.paginate(Bucket=PROCESSED_BUCKET, Prefix=f"{job_id}/"):
                for obj in page.get('Contents', []):
                    # Skip already compressed files
                    if not obj['Key'].endswith('.gz'):
                        objects_to_compress.append(obj['Key'])
            
            # Compress objects
            compressed_count = 0
            for obj_key in objects_to_compress:
                if compress_object(s3_client, obj_key):
                    compressed_count += 1
            
            results[job_id] = {
                'status': 'success',
                'compressed_count': compressed_count,
                'total_objects': len(objects_to_compress)
            }
            
            logger.info(f"Compressed {compressed_count} objects for job {job_id}")
            
        except Exception as e:
            logger.error(f"Error compressing files for job {job_id}: {e}")
            results[job_id] = {
                'status': 'error',
                'error': str(e)
            }
    
    return results

def compress_object(s3_client, obj_key):
    """
    Compresses a single object in S3.
    
    Parameters:
    s3_client (boto3.client): S3 client
    obj_key (str): Object key to compress
    
    Returns:
    bool: True if compression was successful, False otherwise
    """
    try:
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download the object
            download_path = os.path.join(temp_dir, os.path.basename(obj_key))
            s3_client.download_file(PROCESSED_BUCKET, obj_key, download_path)
            
            # Compress the file
            compressed_path = f"{download_path}.gz"
            with open(download_path, 'rb') as f_in:
                with gzip.open(compressed_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            
            # Upload the compressed file
            compressed_key = f"{obj_key}.gz"
            s3_client.upload_file(compressed_path, PROCESSED_BUCKET, compressed_key)
            
            # Delete the original object
            s3_client.delete_object(Bucket=PROCESSED_BUCKET, Key=obj_key)
            
            logger.info(f"Successfully compressed {obj_key} to {compressed_key}")
            return True
            
    except Exception as e:
        logger.error(f"Error compressing object {obj_key}: {e}")
        return False