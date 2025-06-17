import unittest
import json
import os
import numpy as np
import cv2
import torch
from unittest.mock import patch, MagicMock, mock_open, ANY

# Add the src directory to the path so we can import the inference module
import sys
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))
import inference

class TestInference(unittest.TestCase):
    """Test cases for the swinir2 inference.py module"""

    @patch('inference.torch.cuda.is_available')
    def test_device_selection(self, mock_cuda_available):
        """Test device selection based on CUDA availability"""
        # Test when CUDA is available
        mock_cuda_available.return_value = True
        self.assertEqual(inference.device, torch.device('cuda'))
        
        # Test when CUDA is not available
        mock_cuda_available.return_value = False
        # Need to reload the module to re-evaluate the device
        with patch.dict('sys.modules', {'inference': None}):
            import importlib
            importlib.reload(inference)
            self.assertEqual(inference.device, torch.device('cpu'))

    @patch('inference.define_model')
    @patch('inference.os.path.exists')
    def test_model_fn_default_variant(self, mock_exists, mock_define_model):
        """Test model_fn with default model variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function
        model = inference.model_fn('/path/to/models')
        
        # Verify the result
        self.assertEqual(model, mock_model)
        
        # Verify mocks were called correctly
        mock_define_model.assert_called_once_with(
            '/path/to/models/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth', 
            'real_sr', 
            4
        )
        mock_model.to.assert_called_once_with(inference.device)
        mock_model.eval.assert_called_once()

    @patch('inference.define_model')
    @patch('inference.os.path.exists')
    def test_model_fn_specific_variant(self, mock_exists, mock_define_model):
        """Test model_fn with a specific model variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function with a specific variant
        model = inference.model_fn('/path/to/models', 'classical_sr')
        
        # Verify the result
        self.assertEqual(model, mock_model)
        
        # Verify mocks were called correctly
        mock_define_model.assert_called_once_with(
            '/path/to/models/Swin2SR_ClassicalSR_X4_64_PSNR.pth', 
            'classical_sr', 
            4
        )
        mock_model.to.assert_called_once_with(inference.device)
        mock_model.eval.assert_called_once()

    @patch('inference.define_model')
    @patch('inference.os.path.exists')
    def test_model_fn_unknown_variant(self, mock_exists, mock_define_model):
        """Test model_fn with an unknown model variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function with an unknown variant
        model = inference.model_fn('/path/to/models', 'unknown_variant')
        
        # Verify the result
        self.assertEqual(model, mock_model)
        
        # Verify mocks were called correctly - should use default variant
        mock_define_model.assert_called_once_with(
            '/path/to/models/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth', 
            'real_sr', 
            4
        )
        mock_model.to.assert_called_once_with(inference.device)
        mock_model.eval.assert_called_once()

    @patch('inference.define_model')
    @patch('inference.os.path.exists')
    def test_model_fn_file_not_found(self, mock_exists, mock_define_model):
        """Test model_fn when model file is not found"""
        # Setup mocks
        mock_exists.return_value = False
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function
        model = inference.model_fn('/path/to/models', 'classical_sr')
        
        # Verify the result
        self.assertEqual(model, mock_model)
        
        # Verify mocks were called correctly - should fall back to default variant
        mock_define_model.assert_called_once_with(
            '/path/to/models/Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth', 
            'real_sr', 
            4
        )
        mock_model.to.assert_called_once_with(inference.device)
        mock_model.eval.assert_called_once()

    def test_input_fn_single_image(self):
        """Test input_fn with a single image request"""
        # Create a test request
        request_body = json.dumps({
            'input_file_path': 's3://test-bucket/input.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        })
        request_content_type = "application/json"
        
        # Call the function
        result = inference.input_fn(request_body, request_content_type)
        
        # Verify the result is a list with one item
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['input_file_path'], 's3://test-bucket/input.png')

    def test_input_fn_batch(self):
        """Test input_fn with a batch request"""
        # Create a test batch request
        request_body = json.dumps([
            {
                'input_file_path': 's3://test-bucket/input1.png',
                'output_file_path': 's3://test-bucket/output1.png',
                'job_id': 'test-job-1',
                'batch_id': 'test-batch-1'
            },
            {
                'input_file_path': 's3://test-bucket/input2.png',
                'output_file_path': 's3://test-bucket/output2.png',
                'job_id': 'test-job-2',
                'batch_id': 'test-batch-2'
            }
        ])
        request_content_type = "application/json"
        
        # Call the function
        result = inference.input_fn(request_body, request_content_type)
        
        # Verify the result is a list with two items
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['input_file_path'], 's3://test-bucket/input1.png')
        self.assertEqual(result[1]['input_file_path'], 's3://test-bucket/input2.png')

    def test_input_fn_unsupported_content_type(self):
        """Test input_fn with an unsupported content type"""
        # Create a test request
        request_body = "test data"
        request_content_type = "text/plain"
        
        # Call the function and expect an exception
        with self.assertRaises(ValueError):
            inference.input_fn(request_body, request_content_type)

    @patch('inference.boto3.client')
    @patch('inference.os.path.exists')
    def test_download_from_s3_cached(self, mock_exists, mock_boto3_client):
        """Test download_from_s3 when file is already cached"""
        # Setup mocks
        mock_exists.return_value = True
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Call the function
        result = inference.download_from_s3(s3_uri, local_path)
        
        # Verify the result
        self.assertEqual(result, local_path)
        
        # Verify S3 client was not called
        mock_boto3_client.assert_not_called()

    @patch('inference.boto3.client')
    @patch('inference.os.path.exists')
    @patch('inference.os.makedirs')
    def test_download_from_s3_not_cached(self, mock_makedirs, mock_exists, mock_boto3_client):
        """Test download_from_s3 when file is not cached"""
        # Setup mocks
        mock_exists.return_value = False
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Call the function
        result = inference.download_from_s3(s3_uri, local_path)
        
        # Verify the result
        self.assertEqual(result, local_path)
        
        # Verify S3 client was called correctly
        mock_boto3_client.assert_called_once()
        mock_s3.download_file.assert_called_once_with('test-bucket', 'test_file.png', local_path)

    @patch('inference.boto3.client')
    def test_upload_to_s3(self, mock_boto3_client):
        """Test upload_to_s3 function"""
        # Setup mocks
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Call the function
        result = inference.upload_to_s3(local_path, s3_uri)
        
        # Verify the result
        self.assertEqual(result, s3_uri)
        
        # Verify S3 client was called correctly
        mock_boto3_client.assert_called_once()
        mock_s3.upload_file.assert_called_once_with(local_path, 'test-bucket', 'test_file.png')

    @patch('inference.process_single_image')
    def test_predict_fn_single_image(self, mock_process_single):
        """Test predict_fn with a single image"""
        # Setup mocks
        mock_process_single.return_value = {
            'status': 200,
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Create input data for a single image
        input_data = [{
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }]
        
        # Create a mock model
        mock_model = MagicMock()
        
        # Call the function
        result = inference.predict_fn(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        
        # Verify process_single_image was called correctly
        mock_process_single.assert_called_once_with(input_data[0], mock_model)

    @patch('inference.concurrent.futures.ThreadPoolExecutor')
    def test_predict_fn_batch(self, mock_executor):
        """Test predict_fn with a batch of images"""
        # Setup mocks for ThreadPoolExecutor
        mock_executor_instance = MagicMock()
        mock_executor.return_value.__enter__.return_value = mock_executor_instance
        
        # Setup mock futures
        mock_future1 = MagicMock()
        mock_future1.result.return_value = {
            'status': 200,
            'output_file_path': 's3://test-bucket/output1.png',
            'job_id': 'test-job-1',
            'batch_id': 'test-batch-1'
        }
        
        mock_future2 = MagicMock()
        mock_future2.result.return_value = {
            'status': 200,
            'output_file_path': 's3://test-bucket/output2.png',
            'job_id': 'test-job-2',
            'batch_id': 'test-batch-2'
        }
        
        # Setup mock for as_completed
        with patch('inference.concurrent.futures.as_completed', return_value=[mock_future1, mock_future2]):
            # Setup mock for submit
            mock_executor_instance.submit.side_effect = [mock_future1, mock_future2]
            
            # Create input data for a batch
            input_data = [
                {
                    'input_file_path': 's3://test-bucket/input1.png',
                    'output_file_path': 's3://test-bucket/output1.png',
                    'job_id': 'test-job-1',
                    'batch_id': 'test-batch-1'
                },
                {
                    'input_file_path': 's3://test-bucket/input2.png',
                    'output_file_path': 's3://test-bucket/output2.png',
                    'job_id': 'test-job-2',
                    'batch_id': 'test-batch-2'
                }
            ]
            
            # Create a mock model
            mock_model = MagicMock()
            
            # Call the function
            result = inference.predict_fn(input_data, mock_model)
            
            # Verify the result
            self.assertIsInstance(result, list)
            self.assertEqual(len(result), 2)
            self.assertEqual(result[0]['output_file_path'], 's3://test-bucket/output1.png')
            self.assertEqual(result[1]['output_file_path'], 's3://test-bucket/output2.png')
            
            # Verify ThreadPoolExecutor was called correctly
            mock_executor.assert_called_once_with(max_workers=2)
            self.assertEqual(mock_executor_instance.submit.call_count, 2)

    @patch('inference.cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('inference.cv2.imwrite')
    @patch('inference.torch.from_numpy')
    def test_process_single_image(self, mock_torch_from_numpy, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image function"""
        # Setup mocks
        mock_download.return_value = '/tmp/test_file.png'
        mock_imread.return_value = np.zeros((64, 64, 3), dtype=np.uint8)  # Create a dummy image
        mock_upload.return_value = 's3://test-bucket/output.png'
        
        # Mock torch operations
        mock_tensor = MagicMock()
        mock_tensor.size.return_value = (1, 3, 64, 64)  # NCHW format
        mock_torch_from_numpy.return_value = mock_tensor
        mock_tensor.float.return_value = mock_tensor
        mock_tensor.unsqueeze.return_value = mock_tensor
        mock_tensor.to.return_value = mock_tensor
        
        # Create a mock model
        mock_model = MagicMock()
        mock_model.return_value = mock_tensor
        
        # Mock tensor operations for output
        mock_tensor.data.squeeze.return_value = mock_tensor
        mock_tensor.float.return_value = mock_tensor
        mock_tensor.cpu.return_value = mock_tensor
        mock_tensor.clamp_.return_value = mock_tensor
        mock_tensor.numpy.return_value = np.zeros((3, 256, 256), dtype=np.float32)  # CHW format
        
        # Create input data
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Call the function
        with patch('inference.torch.cat', return_value=mock_tensor), \
             patch('inference.torch.flip', return_value=mock_tensor), \
             patch('inference.torch.cuda.empty_cache') as mock_empty_cache:
            result = inference.process_single_image(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        self.assertEqual(result['job_id'], 'test-job')
        self.assertEqual(result['batch_id'], 'test-batch')
        
        # Verify mocks were called correctly
        mock_download.assert_called_once_with('s3://test-bucket/test_file.png', '/tmp/test_file.png')
        mock_imread.assert_called_once_with('/tmp/test_file.png', cv2.IMREAD_COLOR)
        mock_model.assert_called_once()
        mock_imwrite.assert_called_once()
        mock_upload.assert_called_once()
        mock_empty_cache.assert_called_once()

    @patch('inference.cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('inference.cv2.imwrite')
    def test_process_single_image_error_handling(self, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image error handling"""
        # Setup mocks to simulate an error during image reading
        mock_download.return_value = '/tmp/test_file.png'
        mock_imread.return_value = None  # Simulate failure to read image
        
        # Create a mock model
        mock_model = MagicMock()
        
        # Create input data
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Call the function
        result = inference.process_single_image(input_data, mock_model)
        
        # Verify the result indicates an error
        self.assertEqual(result['status'], 500)
        self.assertTrue('error' in result)
        self.assertEqual(result['job_id'], 'test-job')
        self.assertEqual(result['batch_id'], 'test-batch')
        
        # Verify mocks were called correctly
        mock_download.assert_called_once()
        mock_imread.assert_called_once()
        mock_imwrite.assert_not_called()
        mock_upload.assert_not_called()

if __name__ == '__main__':
    unittest.main()