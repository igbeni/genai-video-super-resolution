import unittest
import json
import os
import tempfile
from unittest.mock import patch, MagicMock, mock_open
from datetime import datetime, timedelta

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from intermediate_file_compression import lambda_handler, get_completed_jobs, compress_intermediate_files, compress_object

class TestIntermediateFileCompression(unittest.TestCase):
    """Test cases for the intermediate_file_compression Lambda function"""

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'COMPRESSION_AGE_DAYS': '3',
        'ENABLE_COMPRESSION': 'true'
    })
    @patch('intermediate_file_compression.boto3.client')
    @patch('intermediate_file_compression.boto3.resource')
    def test_compression_enabled(self, mock_boto3_resource, mock_boto3_client):
        """Test when compression is enabled"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {
            'Items': [
                {
                    'JobId': 'job-123',
                    'Status': 'COMPLETED',
                    'UpdatedAt': (datetime.utcnow() - timedelta(days=5)).isoformat()
                }
            ]
        }
        
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
        
        # Mock compress_object function to avoid actual file operations
        with patch('intermediate_file_compression.compress_object', return_value=True) as mock_compress:
            # Call the Lambda function
            response = lambda_handler({}, {})
            
            # Verify the response
            self.assertEqual(response['statusCode'], 200)
            response_body = json.loads(response['body'])
            self.assertEqual(response_body['message'], 'Intermediate file compression completed successfully')
            
            # Verify DynamoDB table was queried
            mock_dynamodb.Table.assert_called_once_with('jobs-table')
            mock_table.scan.assert_called_once()
            
            # Verify S3 client was called to list objects
            mock_s3.get_paginator.assert_called_once_with('list_objects_v2')
            
            # Verify compress_object was called for each object
            self.assertEqual(mock_compress.call_count, 2)

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'COMPRESSION_AGE_DAYS': '3',
        'ENABLE_COMPRESSION': 'false'
    })
    @patch('intermediate_file_compression.boto3.client')
    @patch('intermediate_file_compression.boto3.resource')
    def test_compression_disabled(self, mock_boto3_resource, mock_boto3_client):
        """Test when compression is disabled"""
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Compression is disabled')
        self.assertEqual(response_body['compressed_count'], 0)
        
        # Verify boto3 clients were not called
        mock_boto3_resource.assert_not_called()
        mock_boto3_client.assert_not_called()

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'COMPRESSION_AGE_DAYS': '3',
        'ENABLE_COMPRESSION': 'true'
    })
    @patch('intermediate_file_compression.boto3.client')
    @patch('intermediate_file_compression.boto3.resource')
    def test_no_completed_jobs(self, mock_boto3_resource, mock_boto3_client):
        """Test when there are no completed jobs"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {'Items': []}
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Mock S3 client
        mock_s3 = MagicMock()
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Intermediate file compression completed successfully')
        self.assertEqual(response_body['results'], {})
        
        # Verify DynamoDB table was queried
        mock_dynamodb.Table.assert_called_once_with('jobs-table')
        mock_table.scan.assert_called_once()
        
        # Verify S3 client was not called to list objects
        mock_s3.get_paginator.assert_not_called()

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'COMPRESSION_AGE_DAYS': '3',
        'ENABLE_COMPRESSION': 'true'
    })
    @patch('intermediate_file_compression.boto3.client')
    @patch('intermediate_file_compression.boto3.resource')
    def test_skip_already_compressed_files(self, mock_boto3_resource, mock_boto3_client):
        """Test skipping already compressed files"""
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {
            'Items': [
                {
                    'JobId': 'job-123',
                    'Status': 'COMPLETED',
                    'UpdatedAt': (datetime.utcnow() - timedelta(days=5)).isoformat()
                }
            ]
        }
        
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
                        'Key': 'job-123/frame_0002.png.gz',  # Already compressed
                        'Size': 512,
                        'LastModified': datetime.utcnow()
                    }
                ]
            }
        ]
        
        mock_s3.get_paginator.return_value = mock_paginator
        
        # Configure boto3 mocks
        mock_boto3_resource.return_value = mock_dynamodb
        mock_boto3_client.return_value = mock_s3
        
        # Mock compress_object function to avoid actual file operations
        with patch('intermediate_file_compression.compress_object', return_value=True) as mock_compress:
            # Call the Lambda function
            response = lambda_handler({}, {})
            
            # Verify the response
            self.assertEqual(response['statusCode'], 200)
            response_body = json.loads(response['body'])
            
            # Verify compress_object was called only for the uncompressed file
            self.assertEqual(mock_compress.call_count, 1)
            mock_compress.assert_called_once_with(mock_s3, 'job-123/frame_0001.png')

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket'
    })
    @patch('intermediate_file_compression.tempfile.TemporaryDirectory')
    @patch('intermediate_file_compression.open', new_callable=mock_open)
    @patch('intermediate_file_compression.gzip.open', new_callable=mock_open)
    @patch('intermediate_file_compression.shutil.copyfileobj')
    def test_compress_object(self, mock_copyfileobj, mock_gzip_open, mock_open, mock_temp_dir):
        """Test compressing a single object"""
        # Mock temporary directory
        mock_temp_dir.return_value.__enter__.return_value = '/tmp/test'
        
        # Mock S3 client
        mock_s3 = MagicMock()
        
        # Call the compress_object function
        result = compress_object(mock_s3, 'job-123/frame_0001.png')
        
        # Verify the result
        self.assertTrue(result)
        
        # Verify S3 client was called correctly
        mock_s3.download_file.assert_called_once_with('processed-bucket', 'job-123/frame_0001.png', '/tmp/test/frame_0001.png')
        mock_s3.upload_file.assert_called_once_with('/tmp/test/frame_0001.png.gz', 'processed-bucket', 'job-123/frame_0001.png.gz')
        mock_s3.delete_object.assert_called_once_with(Bucket='processed-bucket', Key='job-123/frame_0001.png')
        
        # Verify file operations were called
        mock_open.assert_called_once()
        mock_gzip_open.assert_called_once()
        mock_copyfileobj.assert_called_once()

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket'
    })
    @patch('intermediate_file_compression.tempfile.TemporaryDirectory')
    def test_compress_object_error(self, mock_temp_dir):
        """Test error handling when compressing an object"""
        # Mock temporary directory
        mock_temp_dir.return_value.__enter__.return_value = '/tmp/test'
        
        # Mock S3 client
        mock_s3 = MagicMock()
        mock_s3.download_file.side_effect = Exception("Test error")
        
        # Call the compress_object function
        result = compress_object(mock_s3, 'job-123/frame_0001.png')
        
        # Verify the result
        self.assertFalse(result)
        
        # Verify S3 client was called
        mock_s3.download_file.assert_called_once()
        mock_s3.upload_file.assert_not_called()
        mock_s3.delete_object.assert_not_called()

    @patch.dict(os.environ, {
        'PROCESSED_BUCKET': 'processed-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'COMPRESSION_AGE_DAYS': '3',
        'ENABLE_COMPRESSION': 'true'
    })
    @patch('intermediate_file_compression.boto3.client')
    @patch('intermediate_file_compression.boto3.resource')
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