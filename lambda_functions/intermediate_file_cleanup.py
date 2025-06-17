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
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
RETENTION_DAYS = int(os.environ.get('RETENTION_DAYS', '7'))  # Default to 7 days

def lambda_handler(event, context):
    """
    Cleans up intermediate files in the processed frames bucket after a job is completed.
    
    Parameters:
    event (dict): Event data, can be triggered by CloudWatch Events or SNS
    context (object): Lambda context
    
    Returns:
    dict: Response containing the cleanup details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize AWS clients
        s3_client = boto3.client('s3')
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Get completed jobs from DynamoDB
        completed_jobs = get_completed_jobs(table)
        logger.info(f"Found {len(completed_jobs)} completed jobs")
        
        # Get orphaned resources
        orphaned_resources = get_orphaned_resources(s3_client, table, completed_jobs)
        logger.info(f"Found {len(orphaned_resources)} orphaned resources")
        
        # Clean up intermediate files for completed jobs
        cleanup_results = cleanup_intermediate_files(s3_client, completed_jobs)
        
        # Clean up orphaned resources
        orphaned_cleanup_results = cleanup_orphaned_resources(s3_client, orphaned_resources)
        
        # Combine results
        all_results = {
            "completed_jobs_cleanup": cleanup_results,
            "orphaned_resources_cleanup": orphaned_cleanup_results
        }
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Intermediate file cleanup completed successfully',
                'results': all_results
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
    Gets a list of completed jobs from DynamoDB.
    
    Parameters:
    table (DynamoDB.Table): DynamoDB table object
    
    Returns:
    list: List of completed job details
    """
    # Query DynamoDB for completed jobs
    response = table.scan(
        FilterExpression="(#status = :completed) AND (#updated_at < :cutoff_date)",
        ExpressionAttributeNames={
            "#status": "Status",
            "#updated_at": "UpdatedAt"
        },
        ExpressionAttributeValues={
            ":completed": "COMPLETED",
            ":cutoff_date": (datetime.utcnow() - timedelta(days=RETENTION_DAYS)).isoformat()
        }
    )
    
    return response.get('Items', [])

def get_orphaned_resources(s3_client, table, completed_jobs):
    """
    Identifies orphaned resources in the processed frames bucket.
    
    Parameters:
    s3_client (boto3.client): S3 client
    table (DynamoDB.Table): DynamoDB table object
    completed_jobs (list): List of completed job details
    
    Returns:
    list: List of orphaned resource details
    """
    # Get all job IDs from DynamoDB
    response = table.scan(
        ProjectionExpression="JobId"
    )
    job_ids = [item['JobId'] for item in response.get('Items', [])]
    
    # List all objects in the processed frames bucket
    orphaned_resources = []
    paginator = s3_client.get_paginator('list_objects_v2')
    
    for page in paginator.paginate(Bucket=PROCESSED_BUCKET):
        for obj in page.get('Contents', []):
            # Extract job ID from object key (assuming format: job_id/...)
            parts = obj['Key'].split('/')
            if len(parts) > 0:
                obj_job_id = parts[0]
                
                # Check if this job ID exists in DynamoDB
                if obj_job_id not in job_ids:
                    # This is an orphaned resource
                    orphaned_resources.append({
                        'Key': obj['Key'],
                        'Size': obj['Size'],
                        'LastModified': obj['LastModified'].isoformat()
                    })
    
    return orphaned_resources

def cleanup_intermediate_files(s3_client, completed_jobs):
    """
    Cleans up intermediate files for completed jobs.
    
    Parameters:
    s3_client (boto3.client): S3 client
    completed_jobs (list): List of completed job details
    
    Returns:
    dict: Cleanup results
    """
    results = {}
    
    for job in completed_jobs:
        job_id = job['JobId']
        
        # List all objects for this job
        objects_to_delete = []
        paginator = s3_client.get_paginator('list_objects_v2')
        
        try:
            for page in paginator.paginate(Bucket=PROCESSED_BUCKET, Prefix=f"{job_id}/"):
                for obj in page.get('Contents', []):
                    objects_to_delete.append({'Key': obj['Key']})
            
            # Delete objects in batches of 1000 (S3 limit)
            deleted_count = 0
            for i in range(0, len(objects_to_delete), 1000):
                batch = objects_to_delete[i:i+1000]
                if batch:
                    s3_client.delete_objects(
                        Bucket=PROCESSED_BUCKET,
                        Delete={
                            'Objects': batch,
                            'Quiet': True
                        }
                    )
                    deleted_count += len(batch)
            
            results[job_id] = {
                'status': 'success',
                'deleted_count': deleted_count
            }
            
            logger.info(f"Cleaned up {deleted_count} objects for job {job_id}")
            
        except Exception as e:
            logger.error(f"Error cleaning up job {job_id}: {e}")
            results[job_id] = {
                'status': 'error',
                'error': str(e)
            }
    
    return results

def cleanup_orphaned_resources(s3_client, orphaned_resources):
    """
    Cleans up orphaned resources.
    
    Parameters:
    s3_client (boto3.client): S3 client
    orphaned_resources (list): List of orphaned resource details
    
    Returns:
    dict: Cleanup results
    """
    results = {
        'total_orphaned': len(orphaned_resources),
        'deleted_count': 0,
        'errors': []
    }
    
    # Delete objects in batches of 1000 (S3 limit)
    objects_to_delete = [{'Key': obj['Key']} for obj in orphaned_resources]
    
    try:
        for i in range(0, len(objects_to_delete), 1000):
            batch = objects_to_delete[i:i+1000]
            if batch:
                s3_client.delete_objects(
                    Bucket=PROCESSED_BUCKET,
                    Delete={
                        'Objects': batch,
                        'Quiet': True
                    }
                )
                results['deleted_count'] += len(batch)
        
        logger.info(f"Cleaned up {results['deleted_count']} orphaned objects")
        
    except Exception as e:
        logger.error(f"Error cleaning up orphaned resources: {e}")
        results['errors'].append(str(e))
    
    return results