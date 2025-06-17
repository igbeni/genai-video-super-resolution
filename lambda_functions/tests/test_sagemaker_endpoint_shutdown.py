import unittest
import json
import os
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sagemaker_endpoint_shutdown import lambda_handler, get_active_endpoints, has_exclude_tag, is_endpoint_idle, has_active_jobs

class TestSageMakerEndpointShutdown(unittest.TestCase):
    """Test cases for the sagemaker_endpoint_shutdown Lambda function"""

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_no_active_endpoints(self, mock_boto3_resource, mock_boto3_client):
        """Test when there are no active endpoints"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': []
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        
        # Configure boto3 client mock to return different mocks based on service
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 0 endpoints, shut down 0 idle endpoints')
        self.assertEqual(response_body['results'], [])
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.list_endpoints.assert_called_once()
        mock_sagemaker.delete_endpoint.assert_not_called()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_active_endpoints_not_idle(self, mock_boto3_resource, mock_boto3_client):
        """Test when there are active endpoints but none are idle"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': [
                {
                    'EndpointName': 'test-endpoint-1',
                    'EndpointStatus': 'InService',
                    'CreationTime': datetime.utcnow()
                }
            ]
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {
                    'Sum': 10.0,  # Above threshold
                    'Timestamp': datetime.utcnow()
                }
            ]
        }
        
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Configure boto3 mocks
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 endpoints, shut down 0 idle endpoints')
        self.assertEqual(response_body['results'], [])
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.list_endpoints.assert_called_once()
        mock_sagemaker.delete_endpoint.assert_not_called()
        
        # Verify CloudWatch client was called correctly
        mock_cloudwatch.get_metric_statistics.assert_called_once()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_idle_endpoint_with_active_jobs(self, mock_boto3_resource, mock_boto3_client):
        """Test when there are idle endpoints but they have active jobs"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': [
                {
                    'EndpointName': 'test-endpoint-1',
                    'EndpointStatus': 'InService',
                    'CreationTime': datetime.utcnow()
                }
            ]
        }
        mock_sagemaker.list_tags.return_value = {
            'Tags': []
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {
                    'Sum': 2.0,  # Below threshold
                    'Timestamp': datetime.utcnow()
                }
            ]
        }
        
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {
            'Items': [
                {
                    'JobId': 'job-123',
                    'Status': 'PROCESSING',
                    'Endpoints': 'test-endpoint-1'
                }
            ]
        }
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Configure boto3 mocks
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 endpoints, shut down 0 idle endpoints')
        self.assertEqual(response_body['results'], [])
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.list_endpoints.assert_called_once()
        mock_sagemaker.delete_endpoint.assert_not_called()
        
        # Verify DynamoDB table was queried
        mock_table.scan.assert_called_once()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_idle_endpoint_shutdown(self, mock_boto3_resource, mock_boto3_client):
        """Test shutting down idle endpoints"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': [
                {
                    'EndpointName': 'test-endpoint-1',
                    'EndpointStatus': 'InService',
                    'CreationTime': datetime.utcnow()
                }
            ]
        }
        mock_sagemaker.list_tags.return_value = {
            'Tags': []
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {
                    'Sum': 2.0,  # Below threshold
                    'Timestamp': datetime.utcnow()
                }
            ]
        }
        
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {
            'Items': []  # No active jobs
        }
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Configure boto3 mocks
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 endpoints, shut down 1 idle endpoints')
        self.assertEqual(len(response_body['results']), 1)
        self.assertEqual(response_body['results'][0]['endpoint_name'], 'test-endpoint-1')
        self.assertEqual(response_body['results'][0]['status'], 'shutdown_initiated')
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.list_endpoints.assert_called_once()
        mock_sagemaker.delete_endpoint.assert_called_once_with(EndpointName='test-endpoint-1')

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_excluded_endpoint(self, mock_boto3_resource, mock_boto3_client):
        """Test handling of endpoints with exclude tag"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': [
                {
                    'EndpointName': 'test-endpoint-1',
                    'EndpointStatus': 'InService',
                    'CreationTime': datetime.utcnow()
                }
            ]
        }
        mock_sagemaker.list_tags.return_value = {
            'Tags': [
                {
                    'Key': 'AutoShutdownExclude',
                    'Value': 'true'
                }
            ]
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        
        # Configure boto3 mocks
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 endpoints, shut down 0 idle endpoints')
        self.assertEqual(response_body['results'], [])
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.list_endpoints.assert_called_once()
        mock_sagemaker.list_tags.assert_called_once()
        mock_sagemaker.delete_endpoint.assert_not_called()
        
        # Verify CloudWatch client was not called for excluded endpoint
        mock_cloudwatch.get_metric_statistics.assert_not_called()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    @patch('sagemaker_endpoint_shutdown.boto3.resource')
    def test_no_cloudwatch_data(self, mock_boto3_resource, mock_boto3_client):
        """Test handling of endpoints with no CloudWatch data"""
        # Mock SageMaker client
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.return_value = {
            'Endpoints': [
                {
                    'EndpointName': 'test-endpoint-1',
                    'EndpointStatus': 'InService',
                    'CreationTime': datetime.utcnow()
                }
            ]
        }
        mock_sagemaker.list_tags.return_value = {
            'Tags': []
        }
        
        # Mock CloudWatch client with no datapoints
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': []
        }
        
        # Mock DynamoDB resource and table
        mock_table = MagicMock()
        mock_table.scan.return_value = {
            'Items': []  # No active jobs
        }
        
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # Configure boto3 mocks
        def get_client(service_name):
            if service_name == 'sagemaker':
                return mock_sagemaker
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        mock_boto3_resource.return_value = mock_dynamodb
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        
        # Endpoint with no CloudWatch data should be considered idle and shut down
        self.assertEqual(response_body['message'], 'Checked 1 endpoints, shut down 1 idle endpoints')
        self.assertEqual(len(response_body['results']), 1)
        
        # Verify SageMaker client was called correctly
        mock_sagemaker.delete_endpoint.assert_called_once_with(EndpointName='test-endpoint-1')

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_INVOCATIONS': '5',
        'IDLE_DURATION_MINUTES': '60',
        'ENDPOINT_NAME_PREFIX': 'test-',
        'EXCLUDE_ENDPOINT_TAG': 'AutoShutdownExclude',
        'DYNAMODB_TABLE': 'jobs-table',
        'AWS_REGION': 'us-east-1',
        'AWS_ACCOUNT_ID': '123456789012'
    })
    @patch('sagemaker_endpoint_shutdown.boto3.client')
    def test_aws_service_error(self, mock_boto3_client):
        """Test handling of AWS service errors"""
        # Mock SageMaker client to raise an error
        mock_sagemaker = MagicMock()
        mock_sagemaker.list_endpoints.side_effect = Exception("Test AWS service error")
        
        # Configure boto3 client mock
        mock_boto3_client.return_value = mock_sagemaker
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 500)
        response_body = json.loads(response['body'])
        self.assertTrue('error' in response_body)
        self.assertTrue('Test AWS service error' in response_body['error'])

if __name__ == '__main__':
    unittest.main()