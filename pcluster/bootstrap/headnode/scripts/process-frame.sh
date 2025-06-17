#!/bin/bash
set -e

# Enable error handling
handle_error() {
  local exit_code=$1
  local line_number=$2
  echo "Error occurred at line $line_number with exit code $exit_code"
  aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value 1 --dimensions task_id=${TASK_ID},phase=${MODEL_TYPE}-upscale --metric-name error_count
  exit $exit_code
}

# Enable error trapping
trap 'handle_error $? $LINENO' ERR

# Function for retrying AWS CLI commands
retry_aws_command() {
  local max_attempts=5
  local attempt=1
  local delay=5
  local cmd=$@
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt of $max_attempts: $cmd"
    if eval $cmd; then
      return 0
    else
      echo "Command failed, retrying in $delay seconds..."
      sleep $delay
      attempt=$((attempt + 1))
      delay=$((delay * 2))
    fi
  done
  
  echo "Command failed after $max_attempts attempts"
  return 1
}

# Parse command line arguments
S3_SRC_FRAMES=$1
S3_TGT_FRAMES=$2
BASE_NAME=$3
FRAME_NUMBER=$4
IMAGE_TYPE=$5
TASK_ID=$6
MODEL_TYPE=${7:-"swinir"}  # Default to swinir if not specified
MODEL_VERSION=${8:-"v1"}   # Default to v1 if not specified

# Set batch size based on available memory
MEMORY_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ $MEMORY_MB -gt 30000 ]; then
  BATCH_SIZE=4
elif [ $MEMORY_MB -gt 15000 ]; then
  BATCH_SIZE=2
else
  BATCH_SIZE=1
fi

echo "Processing frame $FRAME_NUMBER with $MODEL_TYPE model version $MODEL_VERSION (batch size: $BATCH_SIZE)"

# Create temporary directories
TEMP_DIR="/tmp/${TASK_ID}_${FRAME_NUMBER}"
mkdir -p ${TEMP_DIR}/input
mkdir -p ${TEMP_DIR}/output
mkdir -p ${TEMP_DIR}/cache

# Determine model endpoint based on model type
if [ "${MODEL_TYPE}" == "realesrgan" ]; then
  MODEL_ENDPOINT="http://localhost:8889/invocations"
  IS_ANIME="yes"
else
  MODEL_ENDPOINT="http://localhost:8888/invocations"
  IS_ANIME="no"
fi

# Calculate frame numbers for batch processing
declare -a FRAMES_TO_PROCESS
FRAMES_TO_PROCESS[0]=${FRAME_NUMBER}

# If batch size > 1, add additional frames to process
if [ $BATCH_SIZE -gt 1 ]; then
  for ((i=1; i<$BATCH_SIZE; i++)); do
    next_frame=$((FRAME_NUMBER + i))
    # Check if next frame exists and is within bounds
    if [ $next_frame -le $(cat /tmp/total_frames 2>/dev/null || echo ${FRAME_NUMBER}) ]; then
      FRAMES_TO_PROCESS[$i]=${next_frame}
    fi
  done
fi

# Process each frame in the batch
for frame in "${FRAMES_TO_PROCESS[@]}"; do
  # Format frame number with leading zeros
  int_len=${#frame}
  task_frame=$(printf "%0${int_len}d" ${frame})
  
  # Define file paths
  local_input_file="${TEMP_DIR}/input/${BASE_NAME}_${task_frame}.${IMAGE_TYPE}"
  local_output_file="${TEMP_DIR}/output/${BASE_NAME}_${task_frame}.${IMAGE_TYPE}"
  s3_input_file="${S3_SRC_FRAMES}/${BASE_NAME}_${task_frame}.${IMAGE_TYPE}"
  s3_output_file="${S3_TGT_FRAMES}/${BASE_NAME}_${task_frame}.${IMAGE_TYPE}"
  
  # Define cache paths
  cache_input_file="${TEMP_DIR}/cache/${BASE_NAME}_${task_frame}.${IMAGE_TYPE}"
  cache_metadata_file="${TEMP_DIR}/cache/${BASE_NAME}_${task_frame}.meta"
  
  # Download input frame from S3 with retry logic
  echo "Downloading frame ${task_frame} from S3..."
  retry_aws_command "aws s3 cp \"${s3_input_file}\" \"${local_input_file}\" --only-show-errors"
  
  # Process the frame
  echo "Processing frame ${task_frame} with ${MODEL_TYPE} model version ${MODEL_VERSION}..."
  
  # Prepare payload based on model type
  if [ "${MODEL_TYPE}" == "realesrgan" ]; then
    payload="{ \"input_file_path\": \"${local_input_file}\", \"output_file_path\": \"${local_output_file}\", \"job_id\": \"${TASK_ID}\", \"batch_id\": \"${frame}\", \"is_anime\": \"${IS_ANIME}\", \"model_version\": \"${MODEL_VERSION}\" }"
  else
    payload="{ \"input_file_path\": \"${local_input_file}\", \"output_file_path\": \"${local_output_file}\", \"job_id\": \"${TASK_ID}\", \"batch_id\": \"${frame}\", \"model_version\": \"${MODEL_VERSION}\" }"
  fi
  
  # Process with retry logic
  max_attempts=3
  attempt=1
  success=false
  
  while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
    echo "Processing attempt $attempt of $max_attempts..."
    
    SECONDS=0
    if curl -s -X POST -d "${payload}" -H "Content-Type: application/json" ${MODEL_ENDPOINT} -o /dev/null; then
      success=true
      duration=$SECONDS
      
      # Upload processed frame to S3 with retry logic
      echo "Uploading processed frame ${task_frame} to S3..."
      retry_aws_command "aws s3 cp \"${local_output_file}\" \"${s3_output_file}\" \
        --storage-class STANDARD \
        --only-show-errors \
        --metadata \"task_id=${TASK_ID},frame=${task_frame},model=${MODEL_TYPE},version=${MODEL_VERSION}\" \
        --sse AES256 \
        --acl bucket-owner-full-control"
      
      # Send metrics to CloudWatch
      aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=${TASK_ID},phase=${MODEL_TYPE}-upscale,model_version=${MODEL_VERSION} --metric-name duration
      aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions phase=${MODEL_TYPE}-upscale,model_version=${MODEL_VERSION} --metric-name duration
    else
      echo "Processing failed, retrying..."
      attempt=$((attempt + 1))
      sleep 5
    fi
  done
  
  if [ "$success" = false ]; then
    echo "Failed to process frame ${task_frame} after ${max_attempts} attempts"
    aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value 1 --dimensions task_id=${TASK_ID},phase=${MODEL_TYPE}-upscale,frame=${task_frame} --metric-name processing_failures
    exit 1
  fi
  
  # Clean up local files
  rm -f "${local_input_file}" "${local_output_file}"
done

# Update DynamoDB with processing status
aws dynamodb update-item \
  --table-name VideoSuperResolutionJobs \
  --key '{"JobId": {"S": "'${TASK_ID}'"}}' \
  --update-expression "SET ProcessedFrames = ProcessedFrames + :inc, UpdatedAt = :t" \
  --expression-attribute-values '{":inc": {"N": "'${#FRAMES_TO_PROCESS[@]}'"}, ":t": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}'

# Clean up temporary directory
rm -rf ${TEMP_DIR}

echo "Successfully processed ${#FRAMES_TO_PROCESS[@]} frames"
exit 0