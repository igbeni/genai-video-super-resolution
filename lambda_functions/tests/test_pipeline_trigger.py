import unittest
import json
import os
from unittest.mock import patch, MagicMock
from datetime import datetime

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from pipeline_trigger import lambda_handler

class TestPipelineTrigger(unittest.TestCase):
    """Test cases for the pipeline_trigger Lambda function"""

    @patch.dict(os.environ, {
        'SOURCE_BUCKET': 'source-bucket',
        'PROCESSED_BUCKET': 'processed-bucket',
        'FINAL_BUCKET': 'final-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'EXTRACT_FRAMES_SNS': 'arn:aws:sns:us-east-1:123456789012:extract-frames'
    })
    @patch('pipeline_trigger.boto3.client')
    @patch('pipeline_trigger.boto3.resource')
    @patch('pipeline_trigger.uuid.uuid4')
    def test_valid_video_upload(self, mock_uuid, mock_boto3_resource, mock_boto3_client):
        """Test processing a valid video upload event"""
        # Setup mocks
        mock_uuid.return_value = "test-job-id-123"
        
        # Mock S3 client
        mock_s3 = MagicMock()
        mock_s3.head_object.return_value = {
            'ContentLength': 1024000,
            'ContentType': 'video/mp4'
        }
        
        # Mock SNS client
        mock_sns = MagicMock()
        
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Configure boto3 client mock to return different mocks based on service
        def get_client(service_name):
            if service_name == 's3':
                return mock_s3
            elif service_name == 'sns':
                return mock_sns
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Create test event
        event = {
            'Records': [
                {
                    's3': {
                        'bucket': {
                            'name': 'source-bucket'
                        },
                        'object': {
                            'key': 'uploads/test-video.mp4'
                        }
                    }
                }
            ]
        }
        
        # Call the Lambda function
        response = lambda_handler(event, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['jobId'], 'test-job-id-123')
        self.assertEqual(response_body['videoName'], 'test-video.mp4')
        self.assertEqual(response_body['status'], 'INITIATED')
        
        # Verify S3 client was called correctly
        mock_s3.head_object.assert_called_once_with(
            Bucket='source-bucket',
            Key='uploads/test-video.mp4'
        )
        
        # Verify DynamoDB table was updated
        mock_dynamodb.Table.assert_called_once_with('jobs-table')
        mock_table.put_item.assert_called_once()
        # Check that the Item parameter contains the expected keys
        item = mock_table.put_item.call_args[1]['Item']
        self.assertEqual(item['JobId'], 'test-job-id-123')
        self.assertEqual(item['VideoName'], 'test-video.mp4')
        self.assertEqual(item['SourceBucket'], 'source-bucket')
        self.assertEqual(item['SourceKey'], 'uploads/test-video.mp4')
        self.assertEqual(item['Status'], 'INITIATED')
        
        # Verify SNS message was published
        mock_sns.publish.assert_called_once()
        # Check that the Message parameter contains the expected data
        message = json.loads(mock_sns.publish.call_args[1]['Message'])
        self.assertEqual(message['jobId'], 'test-job-id-123')
        self.assertEqual(message['videoName'], 'test-video.mp4')
        self.assertEqual(message['sourceBucket'], 'source-bucket')
        self.assertEqual(message['sourceKey'], 'uploads/test-video.mp4')

    @patch.dict(os.environ, {
        'SOURCE_BUCKET': 'source-bucket',
        'PROCESSED_BUCKET': 'processed-bucket',
        'FINAL_BUCKET': 'final-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'EXTRACT_FRAMES_SNS': 'arn:aws:sns:us-east-1:123456789012:extract-frames'
    })
    def test_non_video_file(self):
        """Test handling of non-video file uploads"""
        # Create test event with a non-video file
        event = {
            'Records': [
                {
                    's3': {
                        'bucket': {
                            'name': 'source-bucket'
                        },
                        'object': {
                            'key': 'uploads/document.pdf'
                        }
                    }
                }
            ]
        }
        
        # Call the Lambda function
        response = lambda_handler(event, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Ignoring non-video file: uploads/document.pdf')

    @patch.dict(os.environ, {
        'SOURCE_BUCKET': 'source-bucket',
        'PROCESSED_BUCKET': 'processed-bucket',
        'FINAL_BUCKET': 'final-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'EXTRACT_FRAMES_SNS': 'arn:aws:sns:us-east-1:123456789012:extract-frames'
    })
    def test_invalid_event_format(self):
        """Test handling of invalid event format"""
        # Create test event with missing required fields
        event = {
            'Records': [
                {
                    'not_s3': {}
                }
            ]
        }
        
        # Call the Lambda function
        response = lambda_handler(event, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 400)
        response_body = json.loads(response['body'])
        self.assertTrue('error' in response_body)
        self.assertTrue('Missing key' in response_body['error'])

    @patch.dict(os.environ, {
        'SOURCE_BUCKET': 'source-bucket',
        'PROCESSED_BUCKET': 'processed-bucket',
        'FINAL_BUCKET': 'final-bucket',
        'DYNAMODB_TABLE': 'jobs-table',
        'EXTRACT_FRAMES_SNS': 'arn:aws:sns:us-east-1:123456789012:extract-frames'
    })
    @patch('pipeline_trigger.boto3.client')
    def test_aws_service_error(self, mock_boto3_client):
        """Test handling of AWS service errors"""
        # Setup mock to raise ClientError
        mock_s3 = MagicMock()
        mock_s3.head_object.side_effect = Exception('Test AWS service error')
        
        # Configure boto3 client mock
        mock_boto3_client.return_value = mock_s3
        
        # Create test event
        event = {
            'Records': [
                {
                    's3': {
                        'bucket': {
                            'name': 'source-bucket'
                        },
                        'object': {
                            'key': 'uploads/test-video.mp4'
                        }
                    }
                }
            ]
        }
        
        # Call the Lambda function
        response = lambda_handler(event, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 500)
        response_body = json.loads(response['body'])
        self.assertTrue('error' in response_body)

if __name__ == '__main__':
    unittest.main()