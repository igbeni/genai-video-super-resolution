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
ORPHANED_VOLUME_AGE_HOURS = int(os.environ.get('ORPHANED_VOLUME_AGE_HOURS', '24'))  # Default to 24 hours
ORPHANED_SNAPSHOT_AGE_DAYS = int(os.environ.get('ORPHANED_SNAPSHOT_AGE_DAYS', '7'))  # Default to 7 days
EXCLUDE_VOLUME_TAG_KEY = os.environ.get('EXCLUDE_VOLUME_TAG_KEY', 'KeepOrphaned')
EXCLUDE_VOLUME_TAG_VALUE = os.environ.get('EXCLUDE_VOLUME_TAG_VALUE', 'true')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')  # Optional SNS topic for notifications

def lambda_handler(event, context):
    """
    Monitors for resource leaks and cleans them up.
    
    Parameters:
    event (dict): Event data, typically triggered by CloudWatch Events
    context (object): Lambda context
    
    Returns:
    dict: Response containing the cleanup details or error message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize AWS clients
        ec2_client = boto3.client('ec2')
        sns_client = boto3.client('sns') if SNS_TOPIC_ARN else None
        
        # Find and clean up orphaned EBS volumes
        orphaned_volumes = find_orphaned_volumes(ec2_client)
        logger.info(f"Found {len(orphaned_volumes)} orphaned EBS volumes")
        
        volume_cleanup_results = cleanup_orphaned_volumes(ec2_client, orphaned_volumes)
        
        # Find and clean up orphaned snapshots
        orphaned_snapshots = find_orphaned_snapshots(ec2_client)
        logger.info(f"Found {len(orphaned_snapshots)} orphaned snapshots")
        
        snapshot_cleanup_results = cleanup_orphaned_snapshots(ec2_client, orphaned_snapshots)
        
        # Combine results
        all_results = {
            "orphaned_volumes_cleanup": volume_cleanup_results,
            "orphaned_snapshots_cleanup": snapshot_cleanup_results
        }
        
        # Send notification if SNS topic is configured
        if SNS_TOPIC_ARN and (volume_cleanup_results['deleted_count'] > 0 or snapshot_cleanup_results['deleted_count'] > 0):
            send_notification(sns_client, all_results)
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Resource leak monitoring completed successfully',
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

def find_orphaned_volumes(ec2_client):
    """
    Finds orphaned EBS volumes.
    
    Parameters:
    ec2_client (boto3.client): EC2 client
    
    Returns:
    list: List of orphaned EBS volume details
    """
    # Get all available volumes
    response = ec2_client.describe_volumes(
        Filters=[
            {
                'Name': 'status',
                'Values': ['available']
            }
        ]
    )
    
    orphaned_volumes = []
    cutoff_time = datetime.utcnow() - timedelta(hours=ORPHANED_VOLUME_AGE_HOURS)
    
    for volume in response.get('Volumes', []):
        # Check if volume has been available for longer than the threshold
        if volume.get('CreateTime', datetime.utcnow()) < cutoff_time:
            # Check if volume has exclude tag
            if not has_exclude_tag(volume.get('Tags', [])):
                orphaned_volumes.append(volume)
    
    return orphaned_volumes

def find_orphaned_snapshots(ec2_client):
    """
    Finds orphaned EBS snapshots.
    
    Parameters:
    ec2_client (boto3.client): EC2 client
    
    Returns:
    list: List of orphaned EBS snapshot details
    """
    # Get all snapshots owned by this account
    response = ec2_client.describe_snapshots(
        OwnerIds=['self']
    )
    
    # Get all volume IDs
    volume_response = ec2_client.describe_volumes()
    volume_ids = [volume['VolumeId'] for volume in volume_response.get('Volumes', [])]
    
    orphaned_snapshots = []
    cutoff_time = datetime.utcnow() - timedelta(days=ORPHANED_SNAPSHOT_AGE_DAYS)
    
    for snapshot in response.get('Snapshots', []):
        # Check if snapshot's volume no longer exists
        if snapshot.get('VolumeId') not in volume_ids:
            # Check if snapshot is older than the threshold
            if snapshot.get('StartTime', datetime.utcnow()) < cutoff_time:
                # Check if snapshot has exclude tag
                if not has_exclude_tag(snapshot.get('Tags', [])):
                    orphaned_snapshots.append(snapshot)
    
    return orphaned_snapshots

def has_exclude_tag(tags):
    """
    Checks if a resource has the exclude tag.
    
    Parameters:
    tags (list): List of resource tags
    
    Returns:
    bool: True if the resource has the exclude tag, False otherwise
    """
    for tag in tags:
        if tag.get('Key') == EXCLUDE_VOLUME_TAG_KEY and tag.get('Value') == EXCLUDE_VOLUME_TAG_VALUE:
            return True
    return False

def cleanup_orphaned_volumes(ec2_client, orphaned_volumes):
    """
    Cleans up orphaned EBS volumes.
    
    Parameters:
    ec2_client (boto3.client): EC2 client
    orphaned_volumes (list): List of orphaned EBS volume details
    
    Returns:
    dict: Cleanup results
    """
    results = {
        'total_orphaned': len(orphaned_volumes),
        'deleted_count': 0,
        'errors': []
    }
    
    for volume in orphaned_volumes:
        volume_id = volume['VolumeId']
        
        try:
            ec2_client.delete_volume(VolumeId=volume_id)
            results['deleted_count'] += 1
            logger.info(f"Deleted orphaned volume {volume_id}")
        except Exception as e:
            logger.error(f"Error deleting orphaned volume {volume_id}: {e}")
            results['errors'].append({
                'volume_id': volume_id,
                'error': str(e)
            })
    
    return results

def cleanup_orphaned_snapshots(ec2_client, orphaned_snapshots):
    """
    Cleans up orphaned EBS snapshots.
    
    Parameters:
    ec2_client (boto3.client): EC2 client
    orphaned_snapshots (list): List of orphaned EBS snapshot details
    
    Returns:
    dict: Cleanup results
    """
    results = {
        'total_orphaned': len(orphaned_snapshots),
        'deleted_count': 0,
        'errors': []
    }
    
    for snapshot in orphaned_snapshots:
        snapshot_id = snapshot['SnapshotId']
        
        try:
            ec2_client.delete_snapshot(SnapshotId=snapshot_id)
            results['deleted_count'] += 1
            logger.info(f"Deleted orphaned snapshot {snapshot_id}")
        except Exception as e:
            logger.error(f"Error deleting orphaned snapshot {snapshot_id}: {e}")
            results['errors'].append({
                'snapshot_id': snapshot_id,
                'error': str(e)
            })
    
    return results

def send_notification(sns_client, results):
    """
    Sends a notification about the cleanup results.
    
    Parameters:
    sns_client (boto3.client): SNS client
    results (dict): Cleanup results
    
    Returns:
    None
    """
    volumes_deleted = results['orphaned_volumes_cleanup']['deleted_count']
    snapshots_deleted = results['orphaned_snapshots_cleanup']['deleted_count']
    
    subject = f"Resource Leak Cleanup: {volumes_deleted} volumes, {snapshots_deleted} snapshots"
    
    message = f"""
Resource Leak Monitoring Report

Orphaned Volumes:
- Total found: {results['orphaned_volumes_cleanup']['total_orphaned']}
- Successfully deleted: {volumes_deleted}
- Errors: {len(results['orphaned_volumes_cleanup']['errors'])}

Orphaned Snapshots:
- Total found: {results['orphaned_snapshots_cleanup']['total_orphaned']}
- Successfully deleted: {snapshots_deleted}
- Errors: {len(results['orphaned_snapshots_cleanup']['errors'])}

For more details, please check the CloudWatch logs.
"""
    
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        logger.info(f"Sent notification to SNS topic {SNS_TOPIC_ARN}")
    except Exception as e:
        logger.error(f"Error sending notification: {e}")