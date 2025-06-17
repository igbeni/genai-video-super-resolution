import unittest
import json
import os
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from intermediate_file_cleanup import lambda_handler, get_completed_jobs, get_orphaned_resources, cleanup_intermediate_files, cleanup_orphaned_resources

class TestIntermediateFileCleanup(unittest.TestCase):
    """Test cases for the intermediate_file_cleanup Lambda function"""

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'RETENTION_DAYS': '7'
    })
    @patch('intermediate_file_cleanup.boto3.client')
    @patch('intermediate_file_cleanup.boto3.resource')
    def test_no_completed_jobs(self, mock_boto3_resource, mock_boto3_client):
        """Test when there are no completed jobs"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {'Items': []}
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Mock S3 client
        mock_s3 = MagicMock()
        mock_s3.get_paginator.return_value.paginate.return_value = []
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Intermediate file cleanup completed successfully')
        
        # Verify DynamoDB table was queried
        mock_dynamodb.Table.assert_called_once_with('jobs-table')
        mock_table.scan.assert_called()
        
        # Verify S3 client was not called to delete objects
        mock_s3.delete_objects.assert_not_called()

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'RETENTION_DAYS': '7'
    })
    @patch('intermediate_file_cleanup.boto3.client')
    @patch('intermediate_file_cleanup.boto3.resource')
    def test_completed_jobs_cleanup(self, mock_boto3_resource, mock_boto3_client):
        """Test cleaning up completed jobs"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        
        # First scan for completed jobs
        mock_table.scan.side_effect = [
            {
                'Items': [
                    {
                        'JobId': 'job-123',
                        'Status': 'COMPLETED',
                        'UpdatedAt': (datetime.utcnow() - timedelta(days=10)).isoformat()
                    }
                ]
            },
            {
                'Items': [
                    {
                        'JobId': 'job-123'
                    },
                    {
                        'JobId': 'job-456'
                    }
                ]
            }
        ]
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Mock S3 client
        mock_s3 = MagicMock()
        
        # Mock paginator for listing objects
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = [
            {
                'Contents': [
                    {
                        'Key': 'job-123/frame_0001.png',
                        'Size': 1024,
                        'LastModified': datetime.utcnow()
                    },
                    {
                        'Key': 'job-123/frame_0002.png',
                        'Size': 1024,
                        'LastModified': datetime.utcnow()
                    }
                ]
            }
        ]
        
        mock_s3.get_paginator.return_value = mock_paginator
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Intermediate file cleanup completed successfully')
        
        # Verify DynamoDB table was queried
        mock_dynamodb.Table.assert_called_with('jobs-table')
        
        # Verify S3 client was called to delete objects
        mock_s3.delete_objects.assert_called_once()
        delete_call_args = mock_s3.delete_objects.call_args[1]
        self.assertEqual(delete_call_args['Bucket'], 'processed-bucket')
        self.assertEqual(len(delete_call_args['Delete']['Objects']), 2)
        self.assertEqual(delete_call_args['Delete']['Objects'][0]['Key'], 'job-123/frame_0001.png')
        self.assertEqual(delete_call_args['Delete']['Objects'][1]['Key'], 'job-123/frame_0002.png')

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'RETENTION_DAYS': '7'
    })
    @patch('intermediate_file_cleanup.boto3.client')
    @patch('intermediate_file_cleanup.boto3.resource')
    def test_orphaned_resources_cleanup(self, mock_boto3_resource, mock_boto3_client):
        """Test cleaning up orphaned resources"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        
        # First scan for completed jobs (empty)
        # Second scan for all job IDs
        mock_table.scan.side_effect = [
            {
                'Items': []
            },
            {
                'Items': [
                    {
                        'JobId': 'job-456'
                    }
                ]
            }
        ]
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Mock S3 client
        mock_s3 = MagicMock()
        
        # Mock paginator for listing objects
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = [
            {
                'Contents': [
                    {
                        'Key': 'job-123/frame_0001.png',  # Orphaned (job-123 not in DynamoDB)
                        'Size': 1024,
                        'LastModified': datetime.utcnow()
                    },
                    {
                        'Key': 'job-456/frame_0001.png',  # Not orphaned (job-456 in DynamoDB)
                        'Size': 1024,
                        'LastModified': datetime.utcnow()
                    }
                ]
            }
        ]
        
        mock_s3.get_paginator.return_value = mock_paginator
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Intermediate file cleanup completed successfully')
        
        # Verify DynamoDB table was queried
        mock_dynamodb.Table.assert_called_with('jobs-table')
        
        # Verify S3 client was called to delete objects
        mock_s3.delete_objects.assert_called_once()
        delete_call_args = mock_s3.delete_objects.call_args[1]
        self.assertEqual(delete_call_args['Bucket'], 'processed-bucket')
        self.assertEqual(len(delete_call_args['Delete']['Objects']), 1)
        self.assertEqual(delete_call_args['Delete']['Objects'][0]['Key'], 'job-123/frame_0001.png')

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'RETENTION_DAYS': '7'
    })
    @patch('intermediate_file_cleanup.boto3.client')
    @patch('intermediate_file_cleanup.boto3.resource')
    def test_large_batch_deletion(self, mock_boto3_resource, mock_boto3_client):
        """Test deleting a large batch of objects (over 1000)"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        
        # First scan for completed jobs
        mock_table.scan.side_effect = [
            {
                'Items': [
                    {
                        'JobId': 'job-123',
                        'Status': 'COMPLETED',
                        'UpdatedAt': (datetime.utcnow() - timedelta(days=10)).isoformat()
                    }
                ]
            },
            {
                'Items': [
                    {
                        'JobId': 'job-123'
                    }
                ]
            }
        ]
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Mock S3 client
        mock_s3 = MagicMock()
        
        # Create a large list of objects (over 1000)
        large_object_list = []
        for i in range(1500):
            large_object_list.append({
                'Key': f'job-123/frame_{i:04d}.png',
                'Size': 1024,
                'LastModified': datetime.utcnow()
            })
        
        # Mock paginator for listing objects
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = [
            {
                'Contents': large_object_list
            }
        ]
        
        mock_s3.get_paginator.return_value = mock_paginator
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Intermediate file cleanup completed successfully')
        
        # Verify S3 client was called to delete objects in batches
        # Should be called twice: once for the first 1000 objects, once for the remaining 500
        self.assertEqual(mock_s3.delete_objects.call_count, 2)
        
        # Verify first batch has 1000 objects
        first_batch_args = mock_s3.delete_objects.call_args_list[0][1]
        self.assertEqual(len(first_batch_args['Delete']['Objects']), 1000)
        
        # Verify second batch has 500 objects
        second_batch_args = mock_s3.delete_objects.call_args_list[1][1]
        self.assertEqual(len(second_batch_args['Delete']['Objects']), 500)

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'RETENTION_DAYS': '7'
    })
    @patch('intermediate_file_cleanup.boto3.client')
    @patch('intermediate_file_cleanup.boto3.resource')
    def test_aws_service_error(self, mock_boto3_resource, mock_boto3_client):
        """Test handling of AWS service errors"""
        # Mock DynamoDB resource to raise an error
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.side_effect = Exception("Test AWS service error")
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 500)
        response_body = json.loads(response['body'])
        self.assertTrue('error' in response_body)
        self.assertTrue('Test AWS service error' in response_body['error'])

if __name__ == '__main__':
    unittest.main()