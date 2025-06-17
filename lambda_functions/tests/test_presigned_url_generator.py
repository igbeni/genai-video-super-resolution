import unittest
import json
import os
from unittest.mock import patch, MagicMock

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from presigned_url_generator import lambda_handler

class TestPresignedUrlGenerator(unittest.TestCase):
    """Test cases for the presigned_url_generator Lambda function"""

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    @patch('presigned_url_generator.boto3.client')
    def test_generate_presigned_url_query_params(self, mock_boto3_client):
        """Test generating a presigned URL with query string parameters"""
        # Setup mock
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.return_value = 'https://test-bucket.s3.amazonaws.com/uploads/test.mp4'
        mock_boto3_client.return_value = mock_s3

        # Test event with query string parameters
        event = {
            'queryStringParameters': {
                'fileName': 'test.mp4',
                'contentType': 'video/mp4',
                'expiration': '1800'
            }
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['url'], 'https://test-bucket.s3.amazonaws.com/uploads/test.mp4')
        self.assertEqual(response_body['key'], 'uploads/test.mp4')
        self.assertEqual(response_body['bucket'], 'test-bucket')
        self.assertEqual(response_body['expiresIn'], 1800)

        # Verify the S3 client was called correctly
        mock_boto3_client.assert_called_once_with('s3')
        mock_s3.generate_presigned_url.assert_called_once_with(
            'put_object',
            Params={
                'Bucket': 'test-bucket',
                'Key': 'uploads/test.mp4',
                'ContentType': 'video/mp4'
            },
            ExpiresIn=1800
        )

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    @patch('presigned_url_generator.boto3.client')
    def test_generate_presigned_url_body(self, mock_boto3_client):
        """Test generating a presigned URL with body parameters"""
        # Setup mock
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.return_value = 'https://test-bucket.s3.amazonaws.com/uploads/test.mp4'
        mock_boto3_client.return_value = mock_s3

        # Test event with body parameters
        event = {
            'body': json.dumps({
                'fileName': 'test.mp4',
                'contentType': 'video/mp4',
                'expiration': '1800'
            })
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['url'], 'https://test-bucket.s3.amazonaws.com/uploads/test.mp4')
        self.assertEqual(response_body['key'], 'uploads/test.mp4')
        self.assertEqual(response_body['bucket'], 'test-bucket')
        self.assertEqual(response_body['expiresIn'], 1800)

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    def test_missing_parameters(self):
        """Test handling of missing parameters"""
        # Test event with no parameters
        event = {}

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response
        self.assertEqual(response['statusCode'], 400)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['error'], 'Missing required parameters')

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    def test_missing_filename(self):
        """Test handling of missing fileName parameter"""
        # Test event with missing fileName
        event = {
            'queryStringParameters': {
                'contentType': 'video/mp4',
                'expiration': '1800'
            }
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response
        self.assertEqual(response['statusCode'], 400)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['error'], 'fileName is required')

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    @patch('presigned_url_generator.boto3.client')
    def test_expiration_limits(self, mock_boto3_client):
        """Test handling of expiration limits"""
        # Setup mock
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.return_value = 'https://test-bucket.s3.amazonaws.com/uploads/test.mp4'
        mock_boto3_client.return_value = mock_s3

        # Test event with expiration too low
        event = {
            'queryStringParameters': {
                'fileName': 'test.mp4',
                'contentType': 'video/mp4',
                'expiration': '100'  # Too low, should use default
            }
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response uses default expiration
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['expiresIn'], 3600)  # Default from environment

        # Test event with expiration too high
        event = {
            'queryStringParameters': {
                'fileName': 'test.mp4',
                'contentType': 'video/mp4',
                'expiration': '1000000'  # Too high, should use default
            }
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response uses default expiration
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['expiresIn'], 3600)  # Default from environment

    @patch.dict(os.environ, {'SOURCE_BUCKET': 'test-bucket', 'URL_EXPIRATION': '3600'})
    @patch('presigned_url_generator.boto3.client')
    def test_boto3_client_error(self, mock_boto3_client):
        """Test handling of boto3 client errors"""
        # Setup mock to raise ClientError
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.side_effect = Exception('Test error')
        mock_boto3_client.return_value = mock_s3

        # Test event
        event = {
            'queryStringParameters': {
                'fileName': 'test.mp4',
                'contentType': 'video/mp4'
            }
        }

        # Call the Lambda function
        response = lambda_handler(event, {})

        # Verify the response
        self.assertEqual(response['statusCode'], 500)
        response_body = json.loads(response['body'])
        self.assertTrue('error' in response_body)

if __name__ == '__main__':
    unittest.main()