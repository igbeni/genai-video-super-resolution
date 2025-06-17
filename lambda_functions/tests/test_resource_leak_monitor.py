import unittest
import json
import os
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from resource_leak_monitor import lambda_handler, find_orphaned_volumes, find_orphaned_snapshots, has_exclude_tag, cleanup_orphaned_volumes, cleanup_orphaned_snapshots, send_notification

class TestResourceLeakMonitor(unittest.TestCase):
    """Test cases for the resource_leak_monitor Lambda function"""

    @patch.dict(os.environ, {
        'ORPHANED_VOLUME_AGE_HOURS': '24',
        'ORPHANED_SNAPSHOT_AGE_DAYS': '7',
        'EXCLUDE_VOLUME_TAG_KEY': 'KeepOrphaned',
        'EXCLUDE_VOLUME_TAG_VALUE': 'true',
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:resource-leak-monitor'
    })
    @patch('resource_leak_monitor.boto3.client')
    def test_no_orphaned_resources(self, mock_boto3_client):
        """Test when there are no orphaned resources"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_volumes.return_value = {'Volumes': []}
        mock_ec2.describe_snapshots.return_value = {'Snapshots': []}
        
        # Mock SNS client
        mock_sns = MagicMock()
        
        # Configure boto3 client mock to return different mocks based on service
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'sns':
                return mock_sns
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Resource leak monitoring completed successfully')
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_volumes.assert_called_once()
        mock_ec2.describe_snapshots.assert_called_once()
        
        # Verify no resources were deleted
        mock_ec2.delete_volume.assert_not_called()
        mock_ec2.delete_snapshot.assert_not_called()
        
        # Verify SNS notification was not sent
        mock_sns.publish.assert_not_called()

    @patch.dict(os.environ, {
        'ORPHANED_VOLUME_AGE_HOURS': '24',
        'ORPHANED_SNAPSHOT_AGE_DAYS': '7',
        'EXCLUDE_VOLUME_TAG_KEY': 'KeepOrphaned',
        'EXCLUDE_VOLUME_TAG_VALUE': 'true',
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:resource-leak-monitor'
    })
    @patch('resource_leak_monitor.boto3.client')
    def test_orphaned_volumes(self, mock_boto3_client):
        """Test finding and cleaning up orphaned volumes"""
        # Create a timestamp for testing
        now = datetime.utcnow()
        old_timestamp = now - timedelta(hours=48)  # 48 hours old (beyond the 24-hour threshold)
        
        # Mock EC2 client
        mock_ec2 = MagicMock()
        
        # Mock describe_volumes response with orphaned volumes
        mock_ec2.describe_volumes.return_value = {
            'Volumes': [
                {
                    'VolumeId': 'vol-12345',
                    'State': 'available',
                    'CreateTime': old_timestamp,
                    'Tags': []
                },
                {
                    'VolumeId': 'vol-67890',
                    'State': 'available',
                    'CreateTime': old_timestamp,
                    'Tags': [
                        {
                            'Key': 'KeepOrphaned',
                            'Value': 'true'
                        }
                    ]
                }
            ]
        }
        
        # Mock describe_snapshots response with no orphaned snapshots
        mock_ec2.describe_snapshots.return_value = {'Snapshots': []}
        
        # Mock SNS client
        mock_sns = MagicMock()
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'sns':
                return mock_sns
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        
        # Verify only one volume was deleted (the one without the exclude tag)
        self.assertEqual(response_body['results']['orphaned_volumes_cleanup']['deleted_count'], 1)
        
        # Verify EC2 client was called correctly
        mock_ec2.delete_volume.assert_called_once_with(VolumeId='vol-12345')
        
        # Verify SNS notification was sent
        mock_sns.publish.assert_called_once()

    @patch.dict(os.environ, {
        'ORPHANED_VOLUME_AGE_HOURS': '24',
        'ORPHANED_SNAPSHOT_AGE_DAYS': '7',
        'EXCLUDE_VOLUME_TAG_KEY': 'KeepOrphaned',
        'EXCLUDE_VOLUME_TAG_VALUE': 'true',
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:resource-leak-monitor'
    })
    @patch('resource_leak_monitor.boto3.client')
    def test_orphaned_snapshots(self, mock_boto3_client):
        """Test finding and cleaning up orphaned snapshots"""
        # Create a timestamp for testing
        now = datetime.utcnow()
        old_timestamp = now - timedelta(days=10)  # 10 days old (beyond the 7-day threshold)
        
        # Mock EC2 client
        mock_ec2 = MagicMock()
        
        # Mock describe_volumes response with no orphaned volumes
        mock_ec2.describe_volumes.side_effect = [
            {'Volumes': []},  # First call for finding orphaned volumes
            {'Volumes': []}   # Second call for getting volume IDs for snapshot comparison
        ]
        
        # Mock describe_snapshots response with orphaned snapshots
        mock_ec2.describe_snapshots.return_value = {
            'Snapshots': [
                {
                    'SnapshotId': 'snap-12345',
                    'VolumeId': 'vol-nonexistent',
                    'StartTime': old_timestamp,
                    'Tags': []
                },
                {
                    'SnapshotId': 'snap-67890',
                    'VolumeId': 'vol-nonexistent',
                    'StartTime': old_timestamp,
                    'Tags': [
                        {
                            'Key': 'KeepOrphaned',
                            'Value': 'true'
                        }
                    ]
                }
            ]
        }
        
        # Mock SNS client
        mock_sns = MagicMock()
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'sns':
                return mock_sns
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        
        # Verify only one snapshot was deleted (the one without the exclude tag)
        self.assertEqual(response_body['results']['orphaned_snapshots_cleanup']['deleted_count'], 1)
        
        # Verify EC2 client was called correctly
        mock_ec2.delete_snapshot.assert_called_once_with(SnapshotId='snap-12345')
        
        # Verify SNS notification was sent
        mock_sns.publish.assert_called_once()

    @patch.dict(os.environ, {
        'ORPHANED_VOLUME_AGE_HOURS': '24',
        'ORPHANED_SNAPSHOT_AGE_DAYS': '7',
        'EXCLUDE_VOLUME_TAG_KEY': 'KeepOrphaned',
        'EXCLUDE_VOLUME_TAG_VALUE': 'true',
        'SNS_TOPIC_ARN': ''  # Empty SNS topic ARN
    })
    @patch('resource_leak_monitor.boto3.client')
    def test_no_sns_notification(self, mock_boto3_client):
        """Test when SNS notification is disabled"""
        # Create a timestamp for testing
        now = datetime.utcnow()
        old_timestamp = now - timedelta(hours=48)
        
        # Mock EC2 client
        mock_ec2 = MagicMock()
        
        # Mock describe_volumes response with orphaned volumes
        mock_ec2.describe_volumes.return_value = {
            'Volumes': [
                {
                    'VolumeId': 'vol-12345',
                    'State': 'available',
                    'CreateTime': old_timestamp,
                    'Tags': []
                }
            ]
        }
        
        # Mock describe_snapshots response with no orphaned snapshots
        mock_ec2.describe_snapshots.return_value = {'Snapshots': []}
        
        # Configure boto3 client mock
        mock_boto3_client.return_value = mock_ec2
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        
        # Verify SNS client was not created
        for call in mock_boto3_client.call_args_list:
            self.assertNotEqual(call[0][0], 'sns')

    @patch.dict(os.environ, {
        'ORPHANED_VOLUME_AGE_HOURS': '24',
        'ORPHANED_SNAPSHOT_AGE_DAYS': '7',
        'EXCLUDE_VOLUME_TAG_KEY': 'KeepOrphaned',
        'EXCLUDE_VOLUME_TAG_VALUE': 'true',
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-east-1:123456789012:resource-leak-monitor'
    })
    @patch('resource_leak_monitor.boto3.client')
    def test_error_handling(self, mock_boto3_client):
        """Test error handling during resource cleanup"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        
        # Mock describe_volumes response with orphaned volumes
        mock_ec2.describe_volumes.return_value = {
            'Volumes': [
                {
                    'VolumeId': 'vol-12345',
                    'State': 'available',
                    'CreateTime': datetime.utcnow() - timedelta(hours=48),
                    'Tags': []
                }
            ]
        }
        
        # Mock describe_snapshots response with orphaned snapshots
        mock_ec2.describe_snapshots.return_value = {
            'Snapshots': [
                {
                    'SnapshotId': 'snap-12345',
                    'VolumeId': 'vol-nonexistent',
                    'StartTime': datetime.utcnow() - timedelta(days=10),
                    'Tags': []
                }
            ]
        }
        
        # Mock delete operations to raise exceptions
        mock_ec2.delete_volume.side_effect = Exception("Error deleting volume")
        mock_ec2.delete_snapshot.side_effect = Exception("Error deleting snapshot")
        
        # Mock SNS client
        mock_sns = MagicMock()
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'sns':
                return mock_sns
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        
        # Verify errors were recorded
        self.assertEqual(len(response_body['results']['orphaned_volumes_cleanup']['errors']), 1)
        self.assertEqual(len(response_body['results']['orphaned_snapshots_cleanup']['errors']), 1)
        
        # Verify SNS notification was sent (even though deletions failed)
        mock_sns.publish.assert_called_once()

    def test_has_exclude_tag(self):
        """Test the has_exclude_tag function"""
        # Test with exclude tag
        tags_with_exclude = [
            {
                'Key': 'Name',
                'Value': 'test-volume'
            },
            {
                'Key': 'KeepOrphaned',
                'Value': 'true'
            }
        ]
        self.assertTrue(has_exclude_tag(tags_with_exclude))
        
        # Test without exclude tag
        tags_without_exclude = [
            {
                'Key': 'Name',
                'Value': 'test-volume'
            }
        ]
        self.assertFalse(has_exclude_tag(tags_without_exclude))
        
        # Test with empty tags
        self.assertFalse(has_exclude_tag([]))

if __name__ == '__main__':
    unittest.main()