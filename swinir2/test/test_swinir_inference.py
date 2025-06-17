import unittest
import json
import os
import numpy as np
import cv2
import torch
from unittest.mock import patch, MagicMock, mock_open, ANY

# Add the src directory to the path so we can import the inference module
import sys
src_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src')
sys.path.append(src_path)
# Import the patch for torchvision before importing inference
sys.path.insert(0, src_path)
import patch_torchvision
import inference


class TestInference(unittest.TestCase):
    """Test cases for the swinir2 inference.py module"""

    @patch('inference.torch.cuda.is_available')
    def test_device_selection(self, mock_cuda_available):
        """Test that the correct device is selected based on CUDA availability"""
        # Test with CUDA available
        mock_cuda_available.return_value = True
        self.assertEqual(inference.select_device(), 'cuda')
        
        # Test with CUDA not available
        mock_cuda_available.return_value = False
        self.assertEqual(inference.select_device(), 'cpu')
        
        # Test with environment variable override
        with patch.dict(os.environ, {'FORCE_CPU': '1'}):
            mock_cuda_available.return_value = True
            self.assertEqual(inference.select_device(), 'cpu')

    @patch('inference.define_model')
    @patch('os.path.exists')
    def test_model_fn_default_variant(self, mock_exists, mock_define_model):
        """Test model_fn with default variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function
        model = inference.model_fn('/tmp/model')
        
        # Assertions
        mock_exists.assert_called_with('/tmp/model/swinir_x4.pth')
        mock_define_model.assert_called_with(
            task='lightweight_sr', 
            scale=4, 
            model_path='/tmp/model/swinir_x4.pth',
            device=ANY
        )
        self.assertEqual(model, mock_model)

    @patch('inference.define_model')
    @patch('os.path.exists')
    def test_model_fn_specific_variant(self, mock_exists, mock_define_model):
        """Test model_fn with a specific variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function with environment variable
        with patch.dict(os.environ, {'MODEL_VARIANT': 'real_sr_x4'}):
            model = inference.model_fn('/tmp/model')
        
        # Assertions
        mock_exists.assert_called_with('/tmp/model/swinir_real_sr_x4.pth')
        mock_define_model.assert_called_with(
            task='real_sr', 
            scale=4, 
            model_path='/tmp/model/swinir_real_sr_x4.pth',
            device=ANY
        )
        self.assertEqual(model, mock_model)

    @patch('inference.define_model')
    @patch('os.path.exists')
    def test_model_fn_unknown_variant(self, mock_exists, mock_define_model):
        """Test model_fn with an unknown variant"""
        # Setup mocks
        mock_exists.return_value = True
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function with environment variable
        with patch.dict(os.environ, {'MODEL_VARIANT': 'unknown_variant'}):
            model = inference.model_fn('/tmp/model')
        
        # Assertions
        mock_exists.assert_called_with('/tmp/model/swinir_x4.pth')
        mock_define_model.assert_called_with(
            task='lightweight_sr', 
            scale=4, 
            model_path='/tmp/model/swinir_x4.pth',
            device=ANY
        )
        self.assertEqual(model, mock_model)

    @patch('inference.define_model')
    @patch('os.path.exists')
    def test_model_fn_file_not_found(self, mock_exists, mock_define_model):
        """Test model_fn when the model file doesn't exist"""
        # Setup mocks
        mock_exists.return_value = False
        mock_model = MagicMock()
        mock_define_model.return_value = mock_model
        
        # Call the function
        model = inference.model_fn('/tmp/model')
        
        # Assertions
        mock_exists.assert_called_with('/tmp/model/swinir_x4.pth')
        mock_define_model.assert_called_with(
            task='lightweight_sr', 
            scale=4, 
            model_path='/tmp/model/swinir_x4.pth',
            device=ANY
        )
        self.assertEqual(model, mock_model)

    def test_input_fn_single_image(self):
        """Test input_fn with a single image"""
        # Create a mock image
        image_data = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        encoded_image = cv2.imencode('.jpg', image_data)[1].tobytes()
        
        # Call the function
        result = inference.input_fn(encoded_image, 'application/x-image')
        
        # Assertions
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 1)
        np.testing.assert_array_equal(result[0], image_data)

    def test_input_fn_batch(self):
        """Test input_fn with a batch of images"""
        # Create mock images
        image_data1 = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        image_data2 = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        
        encoded_image1 = cv2.imencode('.jpg', image_data1)[1].tobytes()
        encoded_image2 = cv2.imencode('.jpg', image_data2)[1].tobytes()
        
        # Create a batch
        batch = json.dumps({
            'images': [
                {'data': encoded_image1.hex()},
                {'data': encoded_image2.hex()}
            ]
        })
        
        # Call the function
        result = inference.input_fn(batch.encode('utf-8'), 'application/json')
        
        # Assertions
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 2)
        np.testing.assert_array_equal(result[0], image_data1)
        np.testing.assert_array_equal(result[1], image_data2)

    def test_input_fn_unsupported_content_type(self):
        """Test input_fn with an unsupported content type"""
        # Call the function with an unsupported content type
        with self.assertRaises(ValueError):
            inference.input_fn(b'some data', 'application/unsupported')

    @patch('boto3.client')
    @patch('os.path.exists')
    def test_download_from_s3_cached(self, mock_exists, mock_boto3_client):
        """Test download_from_s3 when the file is already cached"""
        # Setup mocks
        mock_exists.return_value = True
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Call the function
        local_path = inference.download_from_s3('bucket', 'key', '/tmp/cache')
        
        # Assertions
        self.assertEqual(local_path, '/tmp/cache/key')
        mock_exists.assert_called_with('/tmp/cache/key')
        mock_boto3_client.assert_not_called()

    @patch('boto3.client')
    @patch('os.path.exists')
    @patch('os.makedirs')
    def test_download_from_s3_not_cached(self, mock_makedirs, mock_exists, mock_boto3_client):
        """Test download_from_s3 when the file is not cached"""
        # Setup mocks
        mock_exists.return_value = False
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Call the function
        local_path = inference.download_from_s3('bucket', 'key', '/tmp/cache')
        
        # Assertions
        self.assertEqual(local_path, '/tmp/cache/key')
        mock_exists.assert_called_with('/tmp/cache/key')
        mock_boto3_client.assert_called_with('s3')
        mock_s3.download_file.assert_called_with('bucket', 'key', '/tmp/cache/key')
        
        # Test with a key that has a path
        mock_exists.reset_mock()
        mock_boto3_client.reset_mock()
        mock_s3.reset_mock()
        mock_makedirs.reset_mock()
        
        local_path = inference.download_from_s3('bucket', 'path/to/key', '/tmp/cache')
        
        self.assertEqual(local_path, '/tmp/cache/path/to/key')
        mock_makedirs.assert_called_with('/tmp/cache/path/to', exist_ok=True)
        mock_s3.download_file.assert_called_with('bucket', 'path/to/key', '/tmp/cache/path/to/key')

    @patch('boto3.client')
    def test_upload_to_s3(self, mock_boto3_client):
        """Test upload_to_s3"""
        # Setup mocks
        mock_s3 = MagicMock()
        mock_boto3_client.return_value = mock_s3
        
        # Call the function
        inference.upload_to_s3('/tmp/local/file.jpg', 'bucket', 'key.jpg')
        
        # Assertions
        mock_boto3_client.assert_called_with('s3')
        mock_s3.upload_file.assert_called_with('/tmp/local/file.jpg', 'bucket', 'key.jpg')
        
        # Test with content_type
        mock_boto3_client.reset_mock()
        mock_s3.reset_mock()
        
        inference.upload_to_s3('/tmp/local/file.jpg', 'bucket', 'key.jpg', 'image/jpeg')
        
        mock_s3.upload_file.assert_called_with(
            '/tmp/local/file.jpg', 
            'bucket', 
            'key.jpg',
            ExtraArgs={'ContentType': 'image/jpeg'}
        )

    @patch('inference.process_single_image')
    def test_predict_fn_single_image(self, mock_process_single):
        """Test predict_fn with a single image"""
        # Setup mocks
        mock_model = MagicMock()
        mock_image = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        mock_result = np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8)
        mock_process_single.return_value = mock_result
        
        # Call the function
        result = inference.predict_fn([mock_image], mock_model)
        
        # Assertions
        mock_process_single.assert_called_with(mock_image, mock_model)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], mock_result.tobytes())
        
        # Test with output_bucket and output_prefix
        mock_process_single.reset_mock()
        
        with patch.dict(os.environ, {'OUTPUT_BUCKET': 'output-bucket', 'OUTPUT_PREFIX': 'prefix/'}):
            result = inference.predict_fn([mock_image], mock_model)
        
        # Should still process the image and return the result
        mock_process_single.assert_called_with(mock_image, mock_model, s3_bucket='output-bucket', s3_key_prefix='prefix/')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], mock_result.tobytes())

    @patch('concurrent.futures.ThreadPoolExecutor')
    def test_predict_fn_batch(self, mock_executor):
        """Test predict_fn with a batch of images"""
        # Setup mocks
        mock_model = MagicMock()
        mock_images = [
            np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8),
            np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8),
            np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        ]
        mock_results = [
            np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8),
            np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8),
            np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8)
        ]
        
        # Setup the executor mock to return the mock results
        mock_executor_instance = MagicMock()
        mock_executor.return_value.__enter__.return_value = mock_executor_instance
        
        # Setup the future mocks
        mock_futures = []
        for result in mock_results:
            mock_future = MagicMock()
            mock_future.result.return_value = result
            mock_futures.append(mock_future)
        
        mock_executor_instance.submit = MagicMock(side_effect=mock_futures)
        
        # Call the function
        result = inference.predict_fn(mock_images, mock_model)
        
        # Assertions
        self.assertEqual(len(result), 3)
        for i, res in enumerate(result):
            self.assertEqual(res, mock_results[i].tobytes())
        
        # Test with output_bucket and output_prefix
        mock_executor.reset_mock()
        mock_executor_instance.reset_mock()
        
        # Setup the executor mock again
        mock_executor.return_value.__enter__.return_value = mock_executor_instance
        mock_executor_instance.submit = MagicMock(side_effect=mock_futures)
        
        with patch.dict(os.environ, {'OUTPUT_BUCKET': 'output-bucket', 'OUTPUT_PREFIX': 'prefix/'}):
            result = inference.predict_fn(mock_images, mock_model)
        
        # Should process all images and return the results
        self.assertEqual(len(result), 3)
        for i, res in enumerate(result):
            self.assertEqual(res, mock_results[i].tobytes())

    @patch('cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('cv2.imwrite')
    @patch('torch.from_numpy')
    def test_process_single_image(self, mock_torch_from_numpy, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image"""
        # Setup mocks
        mock_model = MagicMock()
        mock_image = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        mock_tensor = MagicMock()
        mock_torch_from_numpy.return_value = mock_tensor
        
        # Setup the model to return a tensor that can be converted to numpy
        mock_output_tensor = MagicMock()
        mock_output_tensor.detach.return_value = mock_output_tensor
        mock_output_tensor.cpu.return_value = mock_output_tensor
        mock_output_tensor.numpy.return_value = np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8)
        mock_model.return_value = mock_output_tensor
        
        # Call the function
        result = inference.process_single_image(mock_image, mock_model)
        
        # Assertions
        mock_torch_from_numpy.assert_called()
        mock_tensor.unsqueeze.assert_called_with(0)
        mock_model.assert_called()
        mock_output_tensor.detach.assert_called()
        mock_output_tensor.cpu.assert_called()
        mock_output_tensor.numpy.assert_called()
        
        # Verify the result
        self.assertEqual(result.shape, (400, 400, 3))
        
        # Test with s3 upload
        mock_torch_from_numpy.reset_mock()
        mock_tensor.reset_mock()
        mock_model.reset_mock()
        mock_output_tensor.reset_mock()
        mock_upload.reset_mock()
        
        # Setup the model again
        mock_torch_from_numpy.return_value = mock_tensor
        mock_output_tensor.detach.return_value = mock_output_tensor
        mock_output_tensor.cpu.return_value = mock_output_tensor
        mock_output_tensor.numpy.return_value = np.random.randint(0, 255, (400, 400, 3), dtype=np.uint8)
        mock_model.return_value = mock_output_tensor
        
        # Call with s3 parameters
        result = inference.process_single_image(mock_image, mock_model, s3_bucket='bucket', s3_key_prefix='prefix/')
        
        # Verify s3 upload was called
        mock_imwrite.assert_called()
        mock_upload.assert_called()

    @patch('cv2.imread')
    @patch('inference.download_from_s3')
    @patch('inference.upload_to_s3')
    @patch('cv2.imwrite')
    def test_process_single_image_error_handling(self, mock_imwrite, mock_upload, mock_download, mock_imread):
        """Test process_single_image error handling"""
        # Setup mocks
        mock_model = MagicMock()
        mock_image = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        
        # Setup the model to raise an exception
        mock_model.side_effect = Exception("Test exception")
        
        # Call the function and verify it handles the exception
        with self.assertLogs(level='ERROR') as cm:
            result = inference.process_single_image(mock_image, mock_model)
            
        # Verify the error was logged
        self.assertTrue(any("Error processing image" in msg for msg in cm.output))
        
        # Verify the result is the original image
        np.testing.assert_array_equal(result, mock_image)
        
        # Test with s3 parameters
        mock_model.reset_mock()
        mock_model.side_effect = Exception("Test exception")
        
        with self.assertLogs(level='ERROR') as cm:
            result = inference.process_single_image(mock_image, mock_model, s3_bucket='bucket', s3_key_prefix='prefix/')
            
        # Verify the error was logged
        self.assertTrue(any("Error processing image" in msg for msg in cm.output))
        
        # Verify the result is the original image
        np.testing.assert_array_equal(result, mock_image)
        
        # Verify no upload was attempted
        mock_upload.assert_not_called()


if __name__ == '__main__':
    unittest.main()