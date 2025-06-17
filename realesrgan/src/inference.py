import torch
import torch.nn as nn
import json
from pathlib import Path
import numpy as np
import cv2
import os
import boto3
import io
import time
import logging
import threading
import concurrent.futures
import gzip
from functools import lru_cache
from botocore.exceptions import ClientError
from botocore.config import Config
from PIL import Image

# Import the patch for torchvision before importing basicsr
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import patch_torchvision

from basicsr.archs.rrdbnet_arch import RRDBNet
from basicsr.utils.download_util import load_file_from_url

from realesrgan.realesrgan import RealESRGANer
from realesrgan.realesrgan.archs.srvgg_arch import SRVGGNetCompact
from gfpgan import GFPGANer

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# S3 client with optimized configuration
s3_config = Config(
    region_name=os.environ.get('AWS_REGION', 'us-east-1'),
    retries={'max_attempts': 10, 'mode': 'adaptive'},
    use_accelerate_endpoint=os.environ.get('USE_S3_ACCELERATION', 'False').lower() == 'true',
    max_pool_connections=100,
    tcp_keepalive=True
)
s3_client = boto3.client('s3', config=s3_config)

# Constants for S3 transfer optimization
MULTIPART_THRESHOLD = 100 * 1024 * 1024  # 100MB
MULTIPART_CHUNKSIZE = 25 * 1024 * 1024   # 25MB
MAX_CONCURRENCY = 10
USE_COMPRESSION = os.environ.get('USE_COMPRESSION', 'False').lower() == 'true'

# RealESR-Gan configuration
netscale = 4
outscale = 4
dni_weight = None

# Cache directories
MODEL_CACHE_DIR = '/tmp/model_cache'
IMAGE_CACHE_DIR = '/tmp/image_cache'
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
os.makedirs(IMAGE_CACHE_DIR, exist_ok=True)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
realesr_gan_model_name = 'RealESRGAN_x4plus.pth'
realesr_gan_face_enhance_model_name = "GFPGANv1.3.pth"
realesr_gan_anime_video_model_name = "realesr-animevideov3.pth"

@lru_cache(maxsize=1)
def load_model(model_name, model_path, model_type):
    """Load a model with caching to improve performance"""
    cache_path = os.path.join(MODEL_CACHE_DIR, f"{model_name}.pt")

    # Check if model exists in cache
    if os.path.exists(cache_path):
        logger.info(f"Using cached model: {cache_path}")
        # For cached models, we'll still use the original model path for loading
        # but log that we're using a cached version

    logger.info(f"Loading model: {model_name} from {model_path}")
    start_time = time.time()

    if model_type == "realesrgan":
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        upsampler = RealESRGANer(
            scale=netscale,
            model_path=model_path,
            dni_weight=dni_weight,
            model=model,
            tile=0,
            tile_pad=10,
            pre_pad=0,
            half=True,
            gpu_id=0)
    elif model_type == "anime":
        model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type='prelu')
        upsampler = RealESRGANer(
            scale=netscale,
            model_path=model_path,
            dni_weight=dni_weight,
            model=model,
            tile=0,
            tile_pad=10,
            pre_pad=0,
            half=True,
            gpu_id=0)
    else:
        raise ValueError(f"Unknown model type: {model_type}")

    elapsed = time.time() - start_time
    logger.info(f"Model {model_name} loaded in {elapsed:.2f} seconds")

    # Save model to cache if it doesn't exist
    if not os.path.exists(cache_path):
        try:
            # Create a symbolic link to the original model file to save disk space
            os.symlink(model_path, cache_path)
            logger.info(f"Created symbolic link for model cache: {cache_path}")
        except Exception as e:
            logger.warning(f"Failed to create model cache: {e}")

    return upsampler

def model_fn(model_dir):
    """Load all models with caching for improved performance"""
    logger.info(f"Loading models from {model_dir}")

    # Define model paths
    realesr_gan_model_path = os.path.join(model_dir, realesr_gan_model_name)
    realesr_gan_face_enhanced_model_path = os.path.join(model_dir, realesr_gan_face_enhance_model_name)
    realesr_gan_anime_model_path = os.path.join(model_dir, realesr_gan_anime_video_model_name)

    # Create cache directory if it doesn't exist
    os.makedirs(MODEL_CACHE_DIR, exist_ok=True)

    # Load models with caching
    try:
        # Load standard model
        real_esr_gan_upsampler = load_model(
            "realesrgan_x4plus", 
            realesr_gan_model_path, 
            "realesrgan"
        )
        logger.info("Loaded RealESRGAN standard model")

        # Load anime model
        real_esr_gan_anime_video_upsampler = load_model(
            "realesrgan_anime", 
            realesr_gan_anime_model_path, 
            "anime"
        )
        logger.info("Loaded RealESRGAN anime model")

        # Load face enhancer model
        face_enhancer = GFPGANer(
            model_path=realesr_gan_face_enhanced_model_path,
            upscale=4,
            arch='clean',
            channel_multiplier=2,
            bg_upsampler=real_esr_gan_upsampler
        )
        logger.info("Loaded face enhancer model")

        # Create model dictionary
        model = {
            'face_enhancer': face_enhancer,
            'realesr_gan': real_esr_gan_upsampler,
            'realesr_gan_anime': real_esr_gan_anime_video_upsampler
        }

        return model
    except Exception as e:
        logger.error(f"Error loading models: {e}")
        raise


def input_fn(request_body, request_content_type):
    if request_content_type == "application/json":
        data = json.loads(request_body)
        return data
    raise ValueError("Unsupported content type: {}".format(request_content_type))


def download_from_s3(s3_uri, local_path):
    """Download a file from S3 to a local path with caching, multipart and compression support"""
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

        # Get file size to determine if multipart download is needed
        try:
            response = s3_client.head_object(Bucket=bucket, Key=key)
            file_size = response['ContentLength']
            logger.info(f"File size: {file_size / (1024 * 1024):.2f} MB")
        except ClientError as e:
            logger.warning(f"Could not determine file size: {e}")
            file_size = 0

        # Download file
        logger.info(f"Downloading {s3_uri} to {local_path}")
        start_time = time.time()

        if USE_COMPRESSION:
            # Download with compression
            logger.info("Using compression for download")
            compressed_key = f"{key}.gz"

            # Check if compressed version exists
            try:
                s3_client.head_object(Bucket=bucket, Key=compressed_key)
                # Use compressed version
                with open(local_path, 'wb') as f_out:
                    s3_obj = s3_client.get_object(Bucket=bucket, Key=compressed_key)
                    with gzip.GzipFile(fileobj=s3_obj['Body'], mode='rb') as f_in:
                        f_out.write(f_in.read())
            except ClientError:
                # Compressed version doesn't exist, use regular download
                if file_size > MULTIPART_THRESHOLD:
                    # Use multipart download for large files
                    transfer_config = boto3.s3.transfer.TransferConfig(
                        multipart_threshold=MULTIPART_THRESHOLD,
                        max_concurrency=MAX_CONCURRENCY,
                        multipart_chunksize=MULTIPART_CHUNKSIZE
                    )
                    s3_client.download_file(
                        bucket, key, local_path,
                        Config=transfer_config
                    )
                else:
                    # Use regular download for small files
                    s3_client.download_file(bucket, key, local_path)
        else:
            # Regular download without compression
            if file_size > MULTIPART_THRESHOLD:
                # Use multipart download for large files
                transfer_config = boto3.s3.transfer.TransferConfig(
                    multipart_threshold=MULTIPART_THRESHOLD,
                    max_concurrency=MAX_CONCURRENCY,
                    multipart_chunksize=MULTIPART_CHUNKSIZE
                )
                s3_client.download_file(
                    bucket, key, local_path,
                    Config=transfer_config
                )
            else:
                # Use regular download for small files
                s3_client.download_file(bucket, key, local_path)

        elapsed = time.time() - start_time
        logger.info(f"Download completed in {elapsed:.2f} seconds")

        return local_path
    except ClientError as e:
        logger.error(f"Error downloading file from S3: {e}")
        raise

def upload_to_s3(local_path, s3_uri):
    """Upload a file from a local path to S3 with multipart and compression support"""
    try:
        # Parse S3 URI
        if s3_uri.startswith('s3://'):
            parts = s3_uri[5:].split('/', 1)
            bucket = parts[0]
            key = parts[1] if len(parts) > 1 else ''
        else:
            # If not an S3 URI, just return the local path
            return local_path

        # Get file size to determine if multipart upload is needed
        file_size = os.path.getsize(local_path)
        logger.info(f"File size: {file_size / (1024 * 1024):.2f} MB")

        # Upload file
        logger.info(f"Uploading {local_path} to {s3_uri}")
        start_time = time.time()

        if USE_COMPRESSION:
            # Upload with compression
            logger.info("Using compression for upload")
            compressed_key = f"{key}.gz"
            compressed_path = f"{local_path}.gz"

            # Compress the file
            with open(local_path, 'rb') as f_in:
                with gzip.open(compressed_path, 'wb') as f_out:
                    f_out.writelines(f_in)

            # Upload the compressed file
            if file_size > MULTIPART_THRESHOLD:
                # Use multipart upload for large files
                transfer_config = boto3.s3.transfer.TransferConfig(
                    multipart_threshold=MULTIPART_THRESHOLD,
                    max_concurrency=MAX_CONCURRENCY,
                    multipart_chunksize=MULTIPART_CHUNKSIZE
                )
                s3_client.upload_file(
                    compressed_path, bucket, compressed_key,
                    Config=transfer_config
                )
            else:
                # Use regular upload for small files
                s3_client.upload_file(compressed_path, bucket, compressed_key)

            # Clean up the compressed file
            os.remove(compressed_path)

            # Also upload the original file for clients that don't support compression
            if file_size > MULTIPART_THRESHOLD:
                transfer_config = boto3.s3.transfer.TransferConfig(
                    multipart_threshold=MULTIPART_THRESHOLD,
                    max_concurrency=MAX_CONCURRENCY,
                    multipart_chunksize=MULTIPART_CHUNKSIZE
                )
                s3_client.upload_file(
                    local_path, bucket, key,
                    Config=transfer_config
                )
            else:
                s3_client.upload_file(local_path, bucket, key)
        else:
            # Regular upload without compression
            if file_size > MULTIPART_THRESHOLD:
                # Use multipart upload for large files
                transfer_config = boto3.s3.transfer.TransferConfig(
                    multipart_threshold=MULTIPART_THRESHOLD,
                    max_concurrency=MAX_CONCURRENCY,
                    multipart_chunksize=MULTIPART_CHUNKSIZE
                )
                s3_client.upload_file(
                    local_path, bucket, key,
                    Config=transfer_config
                )
            else:
                # Use regular upload for small files
                s3_client.upload_file(local_path, bucket, key)

        elapsed = time.time() - start_time
        logger.info(f"Upload completed in {elapsed:.2f} seconds")

        return s3_uri
    except ClientError as e:
        logger.error(f"Error uploading file to S3: {e}")
        raise

def predict_fn(input_data, model):
    """Process an image or batch of images with Real-ESRGAN model"""
    # Check if this is a batch request
    is_batch = 'batch' in input_data and isinstance(input_data['batch'], list)

    if is_batch:
        return process_batch(input_data, model)
    else:
        return process_single_image(input_data, model)

def process_batch(batch_data, model):
    """Process a batch of images for better efficiency"""
    batch_items = batch_data['batch']
    job_id = batch_data.get('job_id', 'batch_job')
    results = []

    # Determine optimal batch size based on available memory
    batch_size = determine_optimal_batch_size()
    logger.info(f"Processing batch with {len(batch_items)} items using batch size of {batch_size}")

    # Process in smaller batches to avoid memory issues
    for i in range(0, len(batch_items), batch_size):
        sub_batch = batch_items[i:i+batch_size]
        logger.info(f"Processing sub-batch {i//batch_size + 1} with {len(sub_batch)} items")

        # Use ThreadPoolExecutor for parallel processing
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(batch_size, MAX_CONCURRENCY)) as executor:
            # Create a list of futures
            future_to_item = {
                executor.submit(process_single_image, 
                                {**item, 'job_id': job_id, 'batch_id': idx + i}, 
                                model): (idx, item) 
                for idx, item in enumerate(sub_batch)
            }

            # Process results as they complete
            for future in concurrent.futures.as_completed(future_to_item):
                idx, item = future_to_item[future]
                try:
                    result = future.result()
                    results.append(result)
                    logger.info(f"Completed processing item {idx + i} in batch")
                except Exception as e:
                    logger.error(f"Error processing batch item {idx + i}: {e}")
                    results.append({
                        "status": 500,
                        "error": str(e),
                        "job_id": job_id,
                        "batch_id": idx + i,
                        "input_file_path": item.get('input_file_path', 'unknown')
                    })

    # Return batch results
    return {
        "status": 200,
        "batch_results": results,
        "job_id": job_id,
        "total_processed": len(results)
    }

def determine_optimal_batch_size():
    """Determine the optimal batch size based on available system resources"""
    # Get available GPU memory
    try:
        if torch.cuda.is_available():
            # Get GPU memory information
            gpu_memory = torch.cuda.get_device_properties(0).total_memory
            free_memory = torch.cuda.memory_reserved(0) - torch.cuda.memory_allocated(0)

            # Calculate batch size based on available memory
            # Assume each image needs approximately 500MB for processing
            memory_per_image = 500 * 1024 * 1024  # 500MB in bytes

            # Use 80% of available memory to be safe
            safe_memory = free_memory * 0.8
            calculated_batch_size = max(1, int(safe_memory / memory_per_image))

            # Cap at a reasonable maximum
            return min(calculated_batch_size, 16)
        else:
            # CPU mode - use a smaller batch size
            return 4
    except Exception as e:
        logger.warning(f"Error determining optimal batch size: {e}, using default")
        return 4  # Default batch size

def process_single_image(input_data, model):
    """Process a single image with Real-ESRGAN model"""
    # Extract input parameters
    input_file_path = input_data['input_file_path']
    output_file_path = input_data['output_file_path']
    job_id = input_data['job_id']
    batch_id = input_data['batch_id']

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
        img = cv2.imread(input_file_path, cv2.IMREAD_UNCHANGED)
        if img is None:
            raise ValueError(f"Failed to read image from {input_file_path}")
    except Exception as e:
        logger.error(f"Error reading image: {e}")
        return {"status": 500, "error": str(e), "job_id": job_id, "batch_id": batch_id}

    # Process the image
    try:
        # Select the appropriate model based on input parameters
        if 'face_enhanced' in input_data and input_data['face_enhanced'].lower() == "yes":
            logger.info("Using face enhancement model")
            face_enhancer = model['face_enhancer'] 
            _, _, output = face_enhancer.enhance(img, has_aligned=False, only_center_face=False, paste_back=True)
        else:
            if ('is_anime' in input_data) and ((input_data['is_anime'].lower() == "yes") or (input_data['is_anime'].lower() == "true")):
                logger.info("Using anime model")
                upsampler = model['realesr_gan_anime']
            else:
                logger.info("Using standard model")
                upsampler = model['realesr_gan'] 

            # Use tile processing for large images to reduce memory usage
            tile_size = input_data.get('tile_size', 0)
            if tile_size == 0 and max(img.shape[0], img.shape[1]) > 1500:
                # Automatically use tiling for large images
                tile_size = 1024
                logger.info(f"Using automatic tiling with size {tile_size} for large image")

            output, _ = upsampler.enhance(img, outscale=outscale, tile=tile_size)

    except RuntimeError as error:
        logger.error(f"Runtime error during processing: {error}")
        logger.error("If you encounter CUDA out of memory, try to set --tile with a smaller number.")
        return {"status": 500, "error": str(error), "job_id": job_id, "batch_id": batch_id}
    except Exception as e:
        logger.error(f"Unexpected error during processing: {e}")
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

    return {
        "status": 200,
        "output_file_path": output_file_path,
        "job_id": job_id,
        "batch_id": batch_id
    }


if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)

    # Load models
    logger.info("Loading models...")
    model = model_fn("/opt/ml/model")
    logger.info("Models loaded successfully")

    # Test with local file
    logger.info("Testing with local file...")
    input_data = {
        'input_file_path': '/workdir/test/SD/frames/0001.png',
        'output_file_path': '/tmp/0001-esrgan-torch.png',
        'job_id': 123,
        'batch_id': 1
    }

    output_data = predict_fn(input_data, model)
    logger.info(f"Local file test result: {output_data}")

    # Test batch processing with local files
    logger.info("Testing batch processing with local files...")
    batch_input_data = {
        'job_id': 'batch_test_123',
        'batch': [
            {
                'input_file_path': '/workdir/test/SD/frames/0001.png',
                'output_file_path': '/tmp/0001-batch-esrgan-torch.png',
                'is_anime': 'no'
            },
            {
                'input_file_path': '/workdir/test/SD/frames/0001.png',
                'output_file_path': '/tmp/0001-batch-anime-esrgan-torch.png',
                'is_anime': 'yes'
            }
        ]
    }

    try:
        batch_output_data = predict_fn(batch_input_data, model)
        logger.info(f"Batch processing test result: {batch_output_data}")
        logger.info(f"Processed {batch_output_data.get('total_processed', 0)} items in batch")
    except Exception as e:
        logger.error(f"Batch processing test failed: {e}")

    # Test with S3 file (if environment variables are set)
    s3_bucket = os.environ.get('TEST_S3_BUCKET')
    if s3_bucket:
        logger.info("Testing with S3 file...")
        s3_input_data = {
            'input_file_path': f's3://{s3_bucket}/test/0001.png',
            'output_file_path': f's3://{s3_bucket}/output/0001-upscaled.png',
            'job_id': 124,
            'batch_id': 2
        }

        try:
            s3_output_data = predict_fn(s3_input_data, model)
            logger.info(f"S3 file test result: {s3_output_data}")

            # Test batch processing with S3 files
            logger.info("Testing batch processing with S3 files...")
            s3_batch_input_data = {
                'job_id': 'batch_test_s3_123',
                'batch': [
                    {
                        'input_file_path': f's3://{s3_bucket}/test/0001.png',
                        'output_file_path': f's3://{s3_bucket}/output/0001-batch-upscaled.png',
                        'is_anime': 'no'
                    },
                    {
                        'input_file_path': f's3://{s3_bucket}/test/0001.png',
                        'output_file_path': f's3://{s3_bucket}/output/0001-batch-anime-upscaled.png',
                        'is_anime': 'yes'
                    }
                ]
            }

            s3_batch_output_data = predict_fn(s3_batch_input_data, model)
            logger.info(f"S3 batch processing test result: {s3_batch_output_data}")
            logger.info(f"Processed {s3_batch_output_data.get('total_processed', 0)} items in S3 batch")
        except Exception as e:
            logger.error(f"S3 test failed: {e}")
    else:
        logger.info("Skipping S3 test (TEST_S3_BUCKET environment variable not set)")

    logger.info("Testing complete")
