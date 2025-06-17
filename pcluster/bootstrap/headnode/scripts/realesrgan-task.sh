#!/bin/bash
set -e

real_src_dir=$1
real_dest_dir=$2
base_name=$3
total_frames=$4
image_type=$5
task_id=$6
s3_src_frames=$7
s3_tgt_frames=$8

int_len=${#total_frames}
task_frame=$(printf "%0${int_len}d" ${SLURM_ARRAY_TASK_ID})
local_input_file="${real_src_dir}/${base_name}_${task_frame}.${image_type}"
local_output_file="${real_dest_dir}/${base_name}_${task_frame}.${image_type}"
s3_input_file="${s3_src_frames}/${base_name}_${task_frame}.${image_type}"
s3_output_file="${s3_tgt_frames}/${base_name}_${task_frame}.${image_type}"

# Create directories if they don't exist
mkdir -p $(dirname "${local_input_file}")
mkdir -p $(dirname "${local_output_file}")

# Use global cache if available, otherwise fall back to local cache
if [ -f "${real_src_dir}/global_cache_dir" ]; then
    GLOBAL_CACHE_DIR=$(cat "${real_src_dir}/global_cache_dir")
    MODEL_CACHE_DIR=$(cat "${real_src_dir}/model_cache_dir")
    FRAME_CACHE_DIR=$(cat "${real_src_dir}/frame_cache_dir")
    TASK_CACHE_DIR=$(cat "${real_src_dir}/task_cache_dir")

    # Ensure cache directories exist
    mkdir -p ${MODEL_CACHE_DIR}
    mkdir -p ${FRAME_CACHE_DIR}
    mkdir -p ${TASK_CACHE_DIR}

    # Define cache paths using global cache
    cache_input_file="${FRAME_CACHE_DIR}/${base_name}_${task_frame}.${image_type}"
    cache_metadata_file="${FRAME_CACHE_DIR}/${base_name}_${task_frame}.meta"

    # Set environment variable for model caching
    export REALESRGAN_MODEL_CACHE="${MODEL_CACHE_DIR}"

    # Create symlink to model cache for the inference endpoint
    if [ ! -L "/tmp/realesrgan_models" ] && [ -d "${MODEL_CACHE_DIR}" ]; then
        ln -sf "${MODEL_CACHE_DIR}" "/tmp/realesrgan_models"
    fi
else
    # Fall back to local cache
    mkdir -p /tmp/realesrgan_cache

    # Define cache paths using local cache
    cache_input_file="/tmp/realesrgan_cache/${base_name}_${task_frame}.${image_type}"
    cache_metadata_file="/tmp/realesrgan_cache/${base_name}_${task_frame}.meta"
fi

# Check if the frame is already in the cache
if [ -f "${cache_input_file}" ] && [ -f "${cache_metadata_file}" ]; then
    cache_etag=$(cat "${cache_metadata_file}")
    s3_etag=$(aws s3api head-object --bucket $(echo ${s3_input_file} | cut -d'/' -f3) --key $(echo ${s3_input_file} | cut -d'/' -f4-) --query ETag --output text 2>/dev/null | tr -d '"')

    if [ "${cache_etag}" = "${s3_etag}" ]; then
        echo "Using cached frame ${task_frame}..."
        cp "${cache_input_file}" "${local_input_file}"
    else
        # Download input frame from S3 with optimized settings
        echo "Cache outdated, downloading frame ${task_frame} from S3..."
        aws s3 cp "${s3_input_file}" "${local_input_file}" \
            --only-show-errors \
            --quiet \
            --endpoint-url https://s3-accelerate.amazonaws.com

        # Update cache
        cp "${local_input_file}" "${cache_input_file}"
        echo "${s3_etag}" > "${cache_metadata_file}"
    fi
else
    # Download input frame from S3 with optimized settings
    echo "Downloading frame ${task_frame} from S3..."
    aws s3 cp "${s3_input_file}" "${local_input_file}" \
        --only-show-errors \
        --quiet \
        --endpoint-url https://s3-accelerate.amazonaws.com

    # Update cache
    cp "${local_input_file}" "${cache_input_file}"
    s3_etag=$(aws s3api head-object --bucket $(echo ${s3_input_file} | cut -d'/' -f3) --key $(echo ${s3_input_file} | cut -d'/' -f4-) --query ETag --output text 2>/dev/null | tr -d '"')
    echo "${s3_etag}" > "${cache_metadata_file}"
fi

# Process the frame
payload="{ \"input_file_path\" : \"${local_input_file}\", \"output_file_path\" : \"${local_output_file}\", \"job_id\" : \"1234\", \"batch_id\" : \"01\", \"is_anime\" : \"yes\" }"

SECONDS=0
time curl -X POST -d ''"$payload"'' -H"Content-Type: application/json" http://localhost:8889/invocations
duration=$SECONDS

# Upload processed frame to S3 with optimized settings
echo "Uploading processed frame ${task_frame} to S3..."
aws s3 cp "${local_output_file}" "${s3_output_file}" \
    --storage-class STANDARD \
    --only-show-errors \
    --metadata "task_id=${task_id},frame=${task_frame}" \
    --sse AES256 \
    --acl bucket-owner-full-control \
    --quiet \
    --endpoint-url https://s3-accelerate.amazonaws.com

# Clean up local files
rm -f "${local_input_file}" "${local_output_file}"

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id,phase=realesrgan-upscale --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions phase=realesrgan-upscale --metric-name duration
