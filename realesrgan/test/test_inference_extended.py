import unittest
import json
import os
import numpy as np
import cv2
import torch
import gzip
import boto3
from unittest.mock import patch, MagicMock, mock_open, ANY

# Add the src directory to the path so we can import the inference module
import sys
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))
import inference

class TestInferenceExtended(unittest.TestCase):
    """Extended test cases for the inference.py module"""

    @patch('inference.boto3.client')
    @patch('inference.os.path.exists')
    @patch('inference.os.makedirs')
    def test_download_from_s3_with_compression(self, mock_makedirs, mock_exists, mock_boto3_client):
        """Test download_from_s3 with compression enabled"""
        # Setup mocks
        mock_exists.return_value = False
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Mock head_object to indicate compressed file exists
        mock_s3.head_object.return_value = {}
        
        # Mock get_object for compressed file
        mock_s3_obj = {'Body': MagicMock()}
        mock_s3.get_object.return_value = mock_s3_obj
        
        # Setup test parameters
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Enable compression
        with patch.dict(os.environ, {'USE_COMPRESSION': 'true'}):
            # Reload the module to apply the environment variable
            import importlib
            importlib.reload(inference)
            
            # Mock gzip file object
            mock_gzip_file = MagicMock()
            mock_gzip_file.read.return_value = b'test data'
            
            # Patch gzip.GzipFile to return our mock
            with patch('inference.gzip.GzipFile', return_value=mock_gzip_file):
                # Call the function
                result = inference.download_from_s3(s3_uri, local_path)
                
                # Verify the result
                self.assertEqual(result, local_path)
                
                # Verify S3 client was called correctly
                mock_boto3_client.assert_called_once()
                mock_s3.head_object.assert_called_once_with(Bucket='test-bucket', Key='test_file.png.gz')
                mock_s3.get_object.assert_called_once_with(Bucket='test-bucket', Key='test_file.png.gz')

    @patch('inference.boto3.client')
    @patch('inference.os.path.exists')
    @patch('inference.os.makedirs')
    @patch('inference.boto3.s3.transfer.TransferConfig')
    def test_download_from_s3_with_multipart(self, mock_transfer_config, mock_makedirs, mock_exists, mock_boto3_client):
        """Test download_from_s3 with multipart download"""
        # Setup mocks
        mock_exists.return_value = False
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Mock head_object to return a large file size
        mock_s3.head_object.return_value = {'ContentLength': inference.MULTIPART_THRESHOLD + 1}
        
        # Setup test parameters
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Disable compression
        with patch.dict(os.environ, {'USE_COMPRESSION': 'false'}):
            # Reload the module to apply the environment variable
            import importlib
            importlib.reload(inference)
            
            # Call the function
            result = inference.download_from_s3(s3_uri, local_path)
            
            # Verify the result
            self.assertEqual(result, local_path)
            
            # Verify S3 client was called correctly
            mock_boto3_client.assert_called_once()
            mock_s3.head_object.assert_called_once_with(Bucket='test-bucket', Key='test_file.png')
            mock_transfer_config.assert_called_once()
            mock_s3.download_file.assert_called_once_with(
                'test-bucket', 'test_file.png', local_path,
                Config=mock_transfer_config.return_value
            )

    @patch('inference.boto3.client')
    @patch('inference.os.path.exists')
    def test_download_from_s3_error_handling(self, mock_exists, mock_boto3_client):
        """Test download_from_s3 error handling"""
        # Setup mocks
        mock_exists.return_value = False
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Mock head_object to raise an error
        mock_s3.head_object.side_effect = boto3.exceptions.ClientError(
            {'Error': {'Code': 'NoSuchKey', 'Message': 'The specified key does not exist.'}},
            'HeadObject'
        )
        
        # Setup test parameters
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Call the function and expect an exception
        with self.assertRaises(boto3.exceptions.ClientError):
            inference.download_from_s3(s3_uri, local_path)

    @patch('inference.boto3.client')
    @patch('inference.os.path.getsize')
    @patch('inference.gzip.open')
    @patch('inference.open', new_callable=mock_open, read_data=b'test data')
    def test_upload_to_s3_with_compression(self, mock_file_open, mock_gzip_open, mock_getsize, mock_boto3_client):
        """Test upload_to_s3 with compression enabled"""
        # Setup mocks
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        mock_getsize.return_value = 1024  # Small file size
        
        # Setup test parameters
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Enable compression
        with patch.dict(os.environ, {'USE_COMPRESSION': 'true'}):
            # Reload the module to apply the environment variable
            import importlib
            importlib.reload(inference)
            
            # Mock os.remove to avoid actual file deletion
            with patch('inference.os.remove'):
                # Call the function
                result = inference.upload_to_s3(local_path, s3_uri)
                
                # Verify the result
                self.assertEqual(result, s3_uri)
                
                # Verify S3 client was called correctly
                mock_boto3_client.assert_called_once()
                mock_file_open.assert_called_once_with(local_path, 'rb')
                mock_gzip_open.assert_called_once_with(f"{local_path}.gz", 'wb')
                
                # Should upload both compressed and original files
                self.assertEqual(mock_s3.upload_file.call_count, 2)
                mock_s3.upload_file.assert_any_call(f"{local_path}.gz", 'test-bucket', 'test_file.png.gz')
                mock_s3.upload_file.assert_any_call(local_path, 'test-bucket', 'test_file.png')

    @patch('inference.boto3.client')
    @patch('inference.os.path.getsize')
    @patch('inference.boto3.s3.transfer.TransferConfig')
    def test_upload_to_s3_with_multipart(self, mock_transfer_config, mock_getsize, mock_boto3_client):
        """Test upload_to_s3 with multipart upload"""
        # Setup mocks
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        mock_getsize.return_value = inference.MULTIPART_THRESHOLD + 1  # Large file size
        
        # Setup test parameters
        local_path = '/tmp/test_file.png'
        s3_uri = 's3://test-bucket/test_file.png'
        
        # Disable compression
        with patch.dict(os.environ, {'USE_COMPRESSION': 'false'}):
            # Reload the module to apply the environment variable
            import importlib
            importlib.reload(inference)
            
            # Call the function
            result = inference.upload_to_s3(local_path, s3_uri)
            
            # Verify the result
            self.assertEqual(result, s3_uri)
            
            # Verify S3 client was called correctly
            mock_boto3_client.assert_called_once()
            mock_transfer_config.assert_called_once()
            mock_s3.upload_file.assert_called_once_with(
                local_path, 'test-bucket', 'test_file.png',
                Config=mock_transfer_config.return_value
            )

    @patch('inference.process_batch')
    @patch('inference.process_single_image')
    def test_predict_fn_single_image(self, mock_process_single, mock_process_batch):
        """Test predict_fn with a single image"""
        # Setup mocks
        mock_process_single.return_value = {
            'status': 200,
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Create input data for a single image
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch'
        }
        
        # Create a mock model
        mock_model = {
            'realesr_gan': MagicMock(),
            'realesr_gan_anime': MagicMock(),
            'face_enhancer': MagicMock()
        }
        
        # Call the function
        result = inference.predict_fn(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        
        # Verify process_single_image was called correctly
        mock_process_single.assert_called_once_with(input_data, mock_model)
        mock_process_batch.assert_not_called()

    @patch('inference.process_batch')
    @patch('inference.process_single_image')
    def test_predict_fn_batch(self, mock_process_single, mock_process_batch):
        """Test predict_fn with a batch of images"""
        # Setup mocks
        mock_process_batch.return_value = {
            'status': 200,
            'batch_results': [
                {'status': 200, 'output_file_path': 's3://test-bucket/output1.png'},
                {'status': 200, 'output_file_path': 's3://test-bucket/output2.png'}
            ],
            'job_id': 'test-job',
            'total_processed': 2
        }
        
        # Create input data for a batch
        input_data = {
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
        result = inference.predict_fn(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['total_processed'], 2)
        
        # Verify process_batch was called correctly
        mock_process_batch.assert_called_once_with(input_data, mock_model)
        mock_process_single.assert_not_called()

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
        mock_model = {
            'realesr_gan': MagicMock(),
            'realesr_gan_anime': MagicMock(),
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

    @patch('inference.cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('inference.cv2.imwrite')
    def test_process_single_image_with_face_enhancement(self, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image with face enhancement"""
        # Setup mocks
        mock_download.return_value = '/tmp/test_file.png'
        mock_imread.return_value = np.zeros((64, 64, 3), dtype=np.uint8)  # Create a dummy image
        mock_upload.return_value = 's3://test-bucket/output.png'
        
        # Create a mock face enhancer
        mock_face_enhancer = MagicMock()
        mock_face_enhancer.enhance.return_value = (None, None, np.zeros((256, 256, 3), dtype=np.uint8))
        
        # Create a mock model
        mock_model = {
            'realesr_gan': MagicMock(),
            'realesr_gan_anime': MagicMock(),
            'face_enhancer': mock_face_enhancer
        }
        
        # Create input data with face enhancement enabled
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch',
            'face_enhanced': 'yes'
        }
        
        # Call the function
        result = inference.process_single_image(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        
        # Verify face enhancer was called
        mock_face_enhancer.enhance.assert_called_once_with(ANY, has_aligned=False, only_center_face=False, paste_back=True)
        
        # Verify other mocks were called correctly
        mock_download.assert_called_once()
        mock_imread.assert_called_once()
        mock_imwrite.assert_called_once()
        mock_upload.assert_called_once()

    @patch('inference.cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('inference.cv2.imwrite')
    def test_process_single_image_with_anime_model(self, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image with anime model"""
        # Setup mocks
        mock_download.return_value = '/tmp/test_file.png'
        mock_imread.return_value = np.zeros((64, 64, 3), dtype=np.uint8)  # Create a dummy image
        mock_upload.return_value = 's3://test-bucket/output.png'
        
        # Create mock upsamplers
        mock_anime_upsampler = MagicMock()
        mock_anime_upsampler.enhance.return_value = (np.zeros((256, 256, 3), dtype=np.uint8), None)
        
        # Create a mock model
        mock_model = {
            'realesr_gan': MagicMock(),
            'realesr_gan_anime': mock_anime_upsampler,
            'face_enhancer': MagicMock()
        }
        
        # Create input data with anime flag
        input_data = {
            'input_file_path': 's3://test-bucket/test_file.png',
            'output_file_path': 's3://test-bucket/output.png',
            'job_id': 'test-job',
            'batch_id': 'test-batch',
            'is_anime': 'yes'
        }
        
        # Call the function
        result = inference.process_single_image(input_data, mock_model)
        
        # Verify the result
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['output_file_path'], 's3://test-bucket/output.png')
        
        # Verify anime upsampler was called
        mock_anime_upsampler.enhance.assert_called_once()
        
        # Verify other mocks were called correctly
        mock_download.assert_called_once()
        mock_imread.assert_called_once()
        mock_imwrite.assert_called_once()
        mock_upload.assert_called_once()

if __name__ == '__main__':
    unittest.main()