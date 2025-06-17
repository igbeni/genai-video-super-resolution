import torch
import torch.nn as nn
import json
from pathlib import Path
from swinir.load_model import define_model
import numpy as np
import cv2
import os
import boto3
import io
import time
import logging
from functools import lru_cache
from botocore.exceptions import ClientError
import concurrent.futures
from typing import List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# S3 client
s3_client = boto3.client('s3')

# Cache directories
MODEL_CACHE_DIR = '/tmp/model_cache'
IMAGE_CACHE_DIR = '/tmp/image_cache'
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
os.makedirs(IMAGE_CACHE_DIR, exist_ok=True)

# SwinIR configuration
scale_factor = 4
window_size = 8

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# Available model variants
MODEL_VARIANTS = {
    'real_sr': {
        'name': 'Swin2SR_RealworldSR_X4_64_BSRGAN_PSNR.pth',
        'description': 'Real-world image super-resolution (4x)',
        'scale': 4
    },
    'classical_sr': {
        'name': 'Swin2SR_ClassicalSR_X4_64_PSNR.pth',
        'description': 'Classical image super-resolution (4x)',
        'scale': 4
    },
    'lightweight_sr': {
        'name': 'Swin2SR_Lightweight_X4_64_PSNR.pth',
        'description': 'Lightweight image super-resolution (4x)',
        'scale': 4
    },
    'color_dn': {
        'name': 'Swin2SR_ColorDN_DFWB_s128w8_PSNR.pth',
        'description': 'Color image denoising',
        'scale': 1
    },
    'jpeg_car': {
        'name': 'Swin2SR_ColorJPEG_s126w7_PSNR.pth',
        'description': 'JPEG compression artifact reduction',
        'scale': 1
    }
}

# Default model variant
DEFAULT_MODEL_VARIANT = 'real_sr'

@lru_cache(maxsize=5)  # Cache up to 5 different models
def model_fn(model_dir, model_variant=None):
    """
    Load a SwinIR model with caching for improved performance

    Args:
        model_dir: Directory containing model files
        model_variant: Model variant to load (one of MODEL_VARIANTS keys)

    Returns:
        Loaded model
    """
    # Use default model variant if none specified
    if model_variant is None or model_variant not in MODEL_VARIANTS:
        if model_variant is not None and model_variant not in MODEL_VARIANTS:
            logger.warning(f"Unknown model variant '{model_variant}'. Using default: {DEFAULT_MODEL_VARIANT}")
        model_variant = DEFAULT_MODEL_VARIANT

    # Get model configuration
    model_config = MODEL_VARIANTS[model_variant]
    model_name = model_config['name']
    model_scale = model_config['scale']

    # Check if model file exists, if not, use the default model
    model_path = os.path.join(model_dir, model_name)
    if not os.path.exists(model_path):
        logger.warning(f"Model file {model_path} not found. Using default model.")
        model_variant = DEFAULT_MODEL_VARIANT
        model_config = MODEL_VARIANTS[model_variant]
        model_name = model_config['name']
        model_scale = model_config['scale']
        model_path = os.path.join(model_dir, model_name)

    logger.info(f"Loading SwinIR model variant: {model_variant} ({model_config['description']})")
    logger.info(f"Model path: {model_path}")

    # Load the model
    model = define_model(model_path, model_variant, model_scale)
    model = model.to(device)
    model.eval()

    return model

def input_fn(request_body, request_content_type):
    if request_content_type == "application/json":
        data = json.loads(request_body)
        # Support both single image and batch processing
        if isinstance(data, list):
            logger.info(f"Received batch request with {len(data)} images")
            return data
        else:
            logger.info("Received single image request")
            return [data]  # Convert to list for consistent handling
    raise ValueError("Unsupported content type: {}".format(request_content_type))


def download_from_s3(s3_uri, local_path):
    """Download a file from S3 to a local path with caching"""
    # Check if file already exists in cache
    if os.path.exists(local_path):
        logger.info(f"Using cached file: {local_path}")
        return local_path

    try:
        # Parse S3 URI
        if s3_uri.startswith('s3://'):
            parts = s3_uri[5:].split('/', 1)
            bucket = parts[0]
            key = parts[1] if len(parts) > 1 else ''
        else:
            # Assume it's a local file
            return s3_uri

        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        # Download file
        logger.info(f"Downloading {s3_uri} to {local_path}")
        start_time = time.time()
        s3_client.download_file(bucket, key, local_path)
        elapsed = time.time() - start_time
        logger.info(f"Download completed in {elapsed:.2f} seconds")

        return local_path
    except ClientError as e:
        logger.error(f"Error downloading file from S3: {e}")
        raise

def upload_to_s3(local_path, s3_uri):
    """Upload a file from a local path to S3"""
    try:
        # Parse S3 URI
        if s3_uri.startswith('s3://'):
            parts = s3_uri[5:].split('/', 1)
            bucket = parts[0]
            key = parts[1] if len(parts) > 1 else ''
        else:
            # If not an S3 URI, just return the local path
            return local_path

        # Upload file
        logger.info(f"Uploading {local_path} to {s3_uri}")
        start_time = time.time()
        s3_client.upload_file(local_path, bucket, key)
        elapsed = time.time() - start_time
        logger.info(f"Upload completed in {elapsed:.2f} seconds")

        return s3_uri
    except ClientError as e:
        logger.error(f"Error uploading file to S3: {e}")
        raise


def predict_fn(input_data_batch, model):
    """Process a batch of images with SwinIR model using parallel processing"""
    start_time = time.time()
    batch_size = len(input_data_batch)
    logger.info(f"Processing batch of {batch_size} images")

    # For small batches, process sequentially
    if batch_size == 1:
        result = process_single_image(input_data_batch[0], model)
        elapsed = time.time() - start_time
        logger.info(f"Processed 1 image in {elapsed:.2f} seconds")
        return result

    # For larger batches, use parallel processing
    results = []
    max_workers = min(batch_size, 4)  # Limit max workers to avoid GPU memory issues

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_item = {
                executor.submit(process_single_image, item, model): item 
                for item in input_data_batch
            }

            # Collect results as they complete
            for future in concurrent.futures.as_completed(future_to_item):
                item = future_to_item[future]
                try:
                    result = future.result()
                    results.append(result)
                    logger.info(f"Completed processing for job_id: {item.get('job_id', 'unknown')}")
                except Exception as e:
                    logger.error(f"Error processing item {item.get('job_id', 'unknown')}: {e}")
                    results.append({
                        "status": 500,
                        "error": str(e),
                        "job_id": item.get('job_id', 'unknown'),
                        "batch_id": item.get('batch_id', 'unknown')
                    })
    except Exception as e:
        logger.error(f"Error in batch processing: {e}")
        return [{
            "status": 500,
            "error": f"Batch processing error: {str(e)}",
            "job_id": "batch",
            "batch_id": "batch"
        }]

    elapsed = time.time() - start_time
    logger.info(f"Processed {len(results)} images in {elapsed:.2f} seconds ({elapsed/len(results):.2f} seconds per image)")

    return results

def process_single_image(input_item, model):
    """Process a single image with SwinIR model"""
    # Extract input parameters
    input_file_path = input_item['input_file_path']
    output_file_path = input_item['output_file_path']
    job_id = input_item['job_id']
    batch_id = input_item['batch_id']

    # Get model variant if specified
    model_variant = input_item.get('model_variant', None)

    # Handle S3 paths
    is_s3_input = input_file_path.startswith('s3://')
    is_s3_output = output_file_path.startswith('s3://')

    # Create local file paths for caching
    imgname, extension = os.path.splitext(os.path.basename(input_file_path))
    local_input_path = os.path.join(IMAGE_CACHE_DIR, f"{imgname}{extension}")
    local_output_path = os.path.join(IMAGE_CACHE_DIR, f"{imgname}_upscaled{extension}")

    # Download from S3 if needed
    if is_s3_input:
        try:
            input_file_path = download_from_s3(input_file_path, local_input_path)
        except Exception as e:
            logger.error(f"Failed to download input file: {e}")
            return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Read the image
    try:
        img_lq = cv2.imread(input_file_path, cv2.IMREAD_COLOR)
        if img_lq is None:
            raise ValueError(f"Failed to read image from {input_file_path}")
        img_lq = img_lq.astype(np.float32) / 255.
    except Exception as e:
        logger.error(f"Error reading image: {e}")
        return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Process the image
    try:
        img_lq = np.transpose(img_lq if img_lq.shape[2] == 1 else img_lq[:, :, [2, 1, 0]], (2, 0, 1))  # HCW-BGR to CHW-RGB
        img_lq = torch.from_numpy(img_lq).float().unsqueeze(0).to(device)  # CHW-RGB to NCHW-RGB

        with torch.no_grad():
            # pad input image to be a multiple of window_size
            _, _, h_old, w_old = img_lq.size()
            h_pad = (h_old // window_size + 1) * window_size - h_old
            w_pad = (w_old // window_size + 1) * window_size - w_old
            img_lq = torch.cat([img_lq, torch.flip(img_lq, [2])], 2)[:, :, :h_old + h_pad, :]
            img_lq = torch.cat([img_lq, torch.flip(img_lq, [3])], 3)[:, :, :, :w_old + w_pad]
            logger.info(f"Image input size: {img_lq.shape}")

            output = model(img_lq)
            output = output[..., :h_old * scale_factor, :w_old * scale_factor]

            output = output.data.squeeze().float().cpu().clamp_(0, 1).numpy()
            if output.ndim == 3:
                output = np.transpose(output[[2, 1, 0], :, :], (1, 2, 0))  # CHW-RGB to HCW-BGR
            output = (output * 255.0).round().astype(np.uint8)  # float32 to uint8
    except Exception as e:
        logger.error(f"Error processing image: {e}")
        return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Save the output locally
    try:
        cv2.imwrite(local_output_path, output)
        logger.info(f"Saved output to {local_output_path}")
    except Exception as e:
        logger.error(f"Error saving output image: {e}")
        return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Upload to S3 if needed
    if is_s3_output:
        try:
            output_file_path = upload_to_s3(local_output_path, output_file_path)
        except Exception as e:
            logger.error(f"Failed to upload output file: {e}")
            return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}
    elif local_output_path != output_file_path:
        # Copy to the specified output path if different from cache path
        try:
            import shutil
            shutil.copy2(local_output_path, output_file_path)
            logger.info(f"Copied output to {output_file_path}")
        except Exception as e:
            logger.error(f"Error copying output file: {e}")
            return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Clean up GPU memory
    torch.cuda.empty_cache()
    logger.info("Torch cache cleared")

    return {
        "status": 200,
        "output_file_path": output_file_path,
        "job_id": job_id,
        "batch_id": batch_id
    }


if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)

    # Load default model
    logger.info("Loading default model...")
    model = model_fn("/opt/ml/model")
    logger.info("Default model loaded successfully")

    # Load models for different variants (if available)
    models = {
        'default': model
    }

    # Try to load other model variants
    for variant in ['classical_sr', 'lightweight_sr', 'color_dn', 'jpeg_car']:
        try:
            logger.info(f"Loading {variant} model...")
            models[variant] = model_fn("/opt/ml/model", variant)
            logger.info(f"{variant} model loaded successfully")
        except Exception as e:
            logger.warning(f"Could not load {variant} model: {e}")

    logger.info(f"Loaded {len(models)} model variants")

    # Test with single local file using different model variants
    logger.info("Testing with single local file using different model variants...")

    # Test each available model variant
    for variant_name, variant_model in models.items():
        logger.info(f"Testing with model variant: {variant_name}")

        # Create a unique output filename for each variant
        output_filename = f"/tmp/0001-swinir-{variant_name}.png"

        single_input_data = [{
            'input_file_path': '/workdir/test/SD/frames/0001.png',
            'output_file_path': output_filename,
            'job_id': f'001-{variant_name}',
            'batch_id': '001',
            'model_variant': variant_name if variant_name != 'default' else None
        }]

        try:
            single_output_data = predict_fn(single_input_data, variant_model)
            logger.info(f"Model variant {variant_name} test result: {single_output_data}")
        except Exception as e:
            logger.error(f"Error testing model variant {variant_name}: {e}")

    # Test with batch of local files using a specific model variant
    test_dir = '/workdir/test/SD/frames'
    if os.path.exists(test_dir):
        # Choose a model variant for batch processing
        # We'll use the default model for batch processing, but you could use any variant
        batch_model_variant = 'default'
        batch_model = models.get(batch_model_variant, model)

        logger.info(f"Testing batch processing with model variant: {batch_model_variant}")

        # Create a batch of test files
        batch_input_data = []
        for i in range(1, 4):  # Process 3 frames if available
            frame_num = f"{i:04d}"
            input_path = f'{test_dir}/{frame_num}.png'
            if os.path.exists(input_path):
                batch_input_data.append({
                    'input_file_path': input_path,
                    'output_file_path': f'/tmp/{frame_num}-swinir-{batch_model_variant}.png',
                    'job_id': f'batch-{i}',
                    'batch_id': f'batch-{batch_model_variant}',
                    'model_variant': batch_model_variant if batch_model_variant != 'default' else None
                })

        if batch_input_data:
            logger.info(f"Processing batch of {len(batch_input_data)} files")
            try:
                batch_output_data = predict_fn(batch_input_data, batch_model)
                logger.info(f"Batch processing results: {batch_output_data}")
            except Exception as e:
                logger.error(f"Error in batch processing: {e}")
        else:
            logger.info("No test files found for batch processing")
    else:
        logger.info(f"Skipping batch test (test directory {test_dir} not found)")

    # Test with S3 file using a specific model variant (if environment variables are set)
    s3_bucket = os.environ.get('TEST_S3_BUCKET')
    if s3_bucket:
        # Choose a model variant for S3 testing
        # We'll use the default model for S3 testing, but you could use any variant
        s3_model_variant = 'default'
        s3_model = models.get(s3_model_variant, model)

        logger.info(f"Testing S3 integration with model variant: {s3_model_variant}")

        s3_input_data = [{
            'input_file_path': f's3://{s3_bucket}/test/0001.png',
            'output_file_path': f's3://{s3_bucket}/output/0001-swinir-{s3_model_variant}.png',
            'job_id': f'002-{s3_model_variant}',
            'batch_id': '002',
            'model_variant': s3_model_variant if s3_model_variant != 'default' else None
        }]

        try:
            s3_output_data = predict_fn(s3_input_data, s3_model)
            logger.info(f"S3 file test result: {s3_output_data}")
        except Exception as e:
            logger.error(f"S3 test failed: {e}")
    else:
        logger.info("Skipping S3 test (TEST_S3_BUCKET environment variable not set)")

    logger.info("Testing complete")
