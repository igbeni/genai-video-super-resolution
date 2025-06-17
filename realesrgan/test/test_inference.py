import unittest
import json
import os
import numpy as np
import cv2
import torch
from unittest.mock import patch, MagicMock, mock_open

# Add the src directory to the path so we can import the inference module
import sys
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))
import inference

class TestInference(unittest.TestCase):
    """Test cases for the inference.py module"""

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

    @patch('inference.cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('inference.cv2.imwrite')
    def test_process_single_image(self, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image function"""
        # Setup mocks
        mock_download.return_value = '/tmp/test_file.png'
        mock_imread.return_value = np.zeros((64, 64, 3), dtype=np.uint8)  # Create a dummy image
        mock_upload.return_value = 's3://test-bucket/output.png'
        
        # Create a mock model
        mock_upsampler = MagicMock()
        mock_upsampler.enhance.return_value = (np.zeros((256, 256, 3), dtype=np.uint8), None)  # 4x upscaled image
        
        mock_model = {
            'realesr_gan': mock_upsampler,
            'realesr_gan_anime': mock_upsampler,
            'face_enhancer': MagicMock()
        }
        
        # Create input data
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Call the function
        result = inference.process_single_image(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        self.assertEqual(result['job_id'], 'test-job')
        self.assertEqual(result['batch_id'], 'test-batch')
        
        # Verify mocks were called correctly
        mock_download.assert_called_once_with('s3://test-bucket/test_file.png', '/tmp/test_file.png')
        mock_imread.assert_called_once_with('/tmp/test_file.png', cv2.IMREAD_UNCHANGED)
        mock_upsampler.enhance.assert_called_once()
        mock_imwrite.assert_called_once()
        mock_upload.assert_called_once()

    @patch('inference.process_single_image')
    def test_process_batch(self, mock_process_single):
        """Test process_batch function"""
        # Setup mocks
        mock_process_single.side_effect = [
            {'status': 200, 'output_file_path': 's3://test-bucket/output1.png', 'job_id': 'test-job', 'batch_id': '1'},
            {'status': 200, 'output_file_path': 's3://test-bucket/output2.png', 'job_id': 'test-job', 'batch_id': '2'}
        ]
        
        # Create input data
        batch_data = {
            'job_id': 'test-job',
            'batch': [
                {'input_file_path': 's3://test-bucket/input1.png', 'output_file_path': 's3://test-bucket/output1.png'},
                {'input_file_path': 's3://test-bucket/input2.png', 'output_file_path': 's3://test-bucket/output2.png'}
            ]
        }
        
        # Create a mock model
        mock_model = {
            'realesr_gan': MagicMock(),
            'realesr_gan_anime': MagicMock(),
            'face_enhancer': MagicMock()
        }
        
        # Call the function
        result = inference.process_batch(batch_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['job_id'], 'test-job')
        self.assertEqual(result['total_processed'], 2)
        self.assertEqual(len(result['batch_results']), 2)
        
        # Verify process_single_image was called correctly
        self.assertEqual(mock_process_single.call_count, 2)

    @patch('inference.torch.cuda.get_device_properties')
    @patch('inference.torch.cuda.memory_reserved')
    @patch('inference.torch.cuda.memory_allocated')
    @patch('inference.torch.cuda.is_available')
    def test_determine_optimal_batch_size_cuda(self, mock_is_available, mock_memory_allocated, 
                                              mock_memory_reserved, mock_get_device_properties):
        """Test determine_optimal_batch_size with CUDA available"""
        # Setup mocks
        mock_is_available.return_value = True
        mock_device_props = MagicMock()
        mock_device_props.total_memory = 8 * 1024 * 1024 * 1024  # 8GB
        mock_get_device_properties.return_value = mock_device_props
        mock_memory_reserved.return_value = 1 * 1024 * 1024 * 1024  # 1GB reserved
        mock_memory_allocated.return_value = 0.5 * 1024 * 1024 * 1024  # 0.5GB allocated
        
        # Call the function
        batch_size = inference.determine_optimal_batch_size()
        
        # Verify the result is reasonable (should be based on available memory)
        self.assertGreater(batch_size, 0)
        self.assertLessEqual(batch_size, 16)  # Should be capped at 16

    @patch('inference.torch.cuda.is_available')
    def test_determine_optimal_batch_size_cpu(self, mock_is_available):
        """Test determine_optimal_batch_size with CUDA not available"""
        # Setup mocks
        mock_is_available.return_value = False
        
        # Call the function
        batch_size = inference.determine_optimal_batch_size()
        
        # Verify the result is the default CPU batch size
        self.assertEqual(batch_size, 4)

    @patch('inference.RRDBNet')
    @patch('inference.RealESRGANer')
    @patch('inference.SRVGGNetCompact')
    @patch('inference.os.path.exists')
    @patch('inference.os.symlink')
    def test_load_model(self, mock_symlink, mock_exists, mock_srvgg, mock_realesrganer, mock_rrdbnet):
        """Test load_model function"""
        # Setup mocks
        mock_exists.return_value = False
        mock_upsampler = MagicMock()
        mock_realesrganer.return_value = mock_upsampler
        
        # Call the function for realesrgan model
        model = inference.load_model('RealESRGAN_x4plus', '/path/to/model.pth', 'realesrgan')
        
        # Verify the result
        self.assertEqual(model, mock_upsampler)
        
        # Verify mocks were called correctly
        mock_rrdbnet.assert_called_once()
        mock_realesrganer.assert_called_once()
        
        # Reset mocks
        mock_rrdbnet.reset_mock()
        mock_realesrganer.reset_mock()
        mock_srvgg.reset_mock()
        
        # Call the function for anime model
        model = inference.load_model('realesr-animevideov3', '/path/to/anime_model.pth', 'anime')
        
        # Verify the result
        self.assertEqual(model, mock_upsampler)
        
        # Verify mocks were called correctly
        mock_rrdbnet.assert_not_called()
        mock_srvgg.assert_called_once()
        mock_realesrganer.assert_called_once()

    @patch('inference.load_model')
    @patch('inference.GFPGANer')
    def test_model_fn(self, mock_gfpganer, mock_load_model):
        """Test model_fn function"""
        # Setup mocks
        mock_upsampler = MagicMock()
        mock_load_model.side_effect = [mock_upsampler, mock_upsampler]
        mock_face_enhancer = MagicMock()
        mock_gfpganer.return_value = mock_face_enhancer
        
        # Call the function
        model = inference.model_fn('/path/to/models')
        
        # Verify the result
        self.assertEqual(model['realesr_gan'], mock_upsampler)
        self.assertEqual(model['realesr_gan_anime'], mock_upsampler)
        self.assertEqual(model['face_enhancer'], mock_face_enhancer)
        
        # Verify mocks were called correctly
        self.assertEqual(mock_load_model.call_count, 2)
        mock_gfpganer.assert_called_once()

    def test_input_fn(self):
        """Test input_fn function"""
        # Test with valid JSON
        request_body = '{"key": "value"}'
        request_content_type = "application/json"
        result = inference.input_fn(request_body, request_content_type)
        self.assertEqual(result, {"key": "value"})
        
        # Test with unsupported content type
        with self.assertRaises(ValueError):
            inference.input_fn(request_body, "text/plain")

if __name__ == '__main__':
    unittest.main()