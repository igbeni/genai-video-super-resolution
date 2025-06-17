import unittest
import json
import os
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

# Import the Lambda function
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from idle_instance_shutdown import lambda_handler, get_running_instances, has_exclude_tag, is_instance_idle

class TestIdleInstanceShutdown(unittest.TestCase):
    """Test cases for the idle_instance_shutdown Lambda function"""

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_PERCENT': '10.0',
        'IDLE_DURATION_MINUTES': '30',
        'INSTANCE_TAG_KEY': 'Name',
        'INSTANCE_TAG_VALUE': '*',
        'EXCLUDE_TAG_KEY': 'AutoShutdownExclude',
        'EXCLUDE_TAG_VALUE': 'true'
    })
    @patch('idle_instance_shutdown.boto3.client')
    def test_no_running_instances(self, mock_boto3_client):
        """Test when there are no running instances"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {
            'Reservations': []
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        
        # Configure boto3 client mock to return different mocks based on service
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 0 instances, shut down 0 idle instances')
        self.assertEqual(response_body['results'], [])
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_instances.assert_called_once()
        mock_ec2.stop_instances.assert_not_called()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_PERCENT': '10.0',
        'IDLE_DURATION_MINUTES': '30',
        'INSTANCE_TAG_KEY': 'Name',
        'INSTANCE_TAG_VALUE': '*',
        'EXCLUDE_TAG_KEY': 'AutoShutdownExclude',
        'EXCLUDE_TAG_VALUE': 'true'
    })
    @patch('idle_instance_shutdown.boto3.client')
    def test_running_instances_not_idle(self, mock_boto3_client):
        """Test when there are running instances but none are idle"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {
            'Reservations': [
                {
                    'Instances': [
                        {
                            'InstanceId': 'i-12345',
                            'Tags': [
                                {
                                    'Key': 'Name',
                                    'Value': 'test-instance'
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {
                    'Average': 15.0,  # Above threshold
                    'Timestamp': datetime.utcnow()
                }
            ]
        }
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 instances, shut down 0 idle instances')
        self.assertEqual(response_body['results'], [])
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_instances.assert_called_once()
        mock_ec2.stop_instances.assert_not_called()
        
        # Verify CloudWatch client was called correctly
        mock_cloudwatch.get_metric_statistics.assert_called_once()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_PERCENT': '10.0',
        'IDLE_DURATION_MINUTES': '30',
        'INSTANCE_TAG_KEY': 'Name',
        'INSTANCE_TAG_VALUE': '*',
        'EXCLUDE_TAG_KEY': 'AutoShutdownExclude',
        'EXCLUDE_TAG_VALUE': 'true'
    })
    @patch('idle_instance_shutdown.boto3.client')
    def test_idle_instance_shutdown(self, mock_boto3_client):
        """Test shutting down idle instances"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {
            'Reservations': [
                {
                    'Instances': [
                        {
                            'InstanceId': 'i-12345',
                            'Tags': [
                                {
                                    'Key': 'Name',
                                    'Value': 'test-instance'
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {
                    'Average': 5.0,  # Below threshold
                    'Timestamp': datetime.utcnow()
                }
            ]
        }
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 instances, shut down 1 idle instances')
        self.assertEqual(len(response_body['results']), 1)
        self.assertEqual(response_body['results'][0]['instance_id'], 'i-12345')
        self.assertEqual(response_body['results'][0]['status'], 'shutdown_initiated')
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_instances.assert_called_once()
        mock_ec2.stop_instances.assert_called_once_with(InstanceIds=['i-12345'])
        
        # Verify CloudWatch client was called correctly
        mock_cloudwatch.get_metric_statistics.assert_called_once()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_PERCENT': '10.0',
        'IDLE_DURATION_MINUTES': '30',
        'INSTANCE_TAG_KEY': 'Name',
        'INSTANCE_TAG_VALUE': '*',
        'EXCLUDE_TAG_KEY': 'AutoShutdownExclude',
        'EXCLUDE_TAG_VALUE': 'true'
    })
    @patch('idle_instance_shutdown.boto3.client')
    def test_excluded_instance(self, mock_boto3_client):
        """Test handling of instances with exclude tag"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {
            'Reservations': [
                {
                    'Instances': [
                        {
                            'InstanceId': 'i-12345',
                            'Tags': [
                                {
                                    'Key': 'Name',
                                    'Value': 'test-instance'
                                },
                                {
                                    'Key': 'AutoShutdownExclude',
                                    'Value': 'true'
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 instances, shut down 0 idle instances')
        self.assertEqual(response_body['results'], [])
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_instances.assert_called_once()
        mock_ec2.stop_instances.assert_not_called()
        
        # Verify CloudWatch client was not called for excluded instance
        mock_cloudwatch.get_metric_statistics.assert_not_called()

    @patch.dict(os.environ, {
        'IDLE_THRESHOLD_PERCENT': '10.0',
        'IDLE_DURATION_MINUTES': '30',
        'INSTANCE_TAG_KEY': 'Name',
        'INSTANCE_TAG_VALUE': '*',
        'EXCLUDE_TAG_KEY': 'AutoShutdownExclude',
        'EXCLUDE_TAG_VALUE': 'true'
    })
    @patch('idle_instance_shutdown.boto3.client')
    def test_no_cloudwatch_data(self, mock_boto3_client):
        """Test handling of instances with no CloudWatch data"""
        # Mock EC2 client
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {
            'Reservations': [
                {
                    'Instances': [
                        {
                            'InstanceId': 'i-12345',
                            'Tags': [
                                {
                                    'Key': 'Name',
                                    'Value': 'test-instance'
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        
        # Mock CloudWatch client with no datapoints
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': []
        }
        
        # Configure boto3 client mock
        def get_client(service_name):
            if service_name == 'ec2':
                return mock_ec2
            elif service_name == 'cloudwatch':
                return mock_cloudwatch
            return MagicMock()
        
        mock_boto3_client.side_effect = get_client
        
        # Call the Lambda function
        response = lambda_handler({}, {})
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertEqual(response_body['message'], 'Checked 1 instances, shut down 0 idle instances')
        self.assertEqual(response_body['results'], [])
        
        # Verify EC2 client was called correctly
        mock_ec2.describe_instances.assert_called_once()
        mock_ec2.stop_instances.assert_not_called()
        
        # Verify CloudWatch client was called
        mock_cloudwatch.get_metric_statistics.assert_called_once()

    def test_has_exclude_tag(self):
        """Test the has_exclude_tag function"""
        # Instance with exclude tag
        instance_with_tag = {
            'InstanceId': 'i-12345',
            'Tags': [
                {
                    'Key': 'AutoShutdownExclude',
                    'Value': 'true'
                }
            ]
        }
        self.assertTrue(has_exclude_tag(instance_with_tag))
        
        # Instance without exclude tag
        instance_without_tag = {
            'InstanceId': 'i-12345',
            'Tags': [
                {
                    'Key': 'Name',
                    'Value': 'test-instance'
                }
            ]
        }
        self.assertFalse(has_exclude_tag(instance_without_tag))
        
        # Instance with no tags
        instance_no_tags = {
            'InstanceId': 'i-12345'
        }
        self.assertFalse(has_exclude_tag(instance_no_tags))

if __name__ == '__main__':
    unittest.main()