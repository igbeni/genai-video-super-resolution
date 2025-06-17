#!/bin/bash
set -e

# Enable error handling
handle_error() {
  local exit_code=$1
  local line_number=$2
  echo "Error occurred at line $line_number with exit code $exit_code"
  echo "error" > ${src_dir}/pipeline_status
  aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value 1 --dimensions task_id=${task_id},phase=upscaling --metric-name error_count
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

usage () {
 echo "frame-super-resolution.sh -s [source_dir containing metadata and S3 paths]"
 echo "For example: frame-super-resolution.sh -s /tmp/task_12345"
}

while getopts ":s:" flag
do
    case "${flag}" in
        s) src_dir=${OPTARG};;
        *)  usage
            exit;
    esac
done
shift "$((OPTIND-1))"

echo upscaling > ${src_dir}/pipeline_status

# Get task information
is_anime=$(cat ${src_dir}/is_anime)
task_id=$(cat ${src_dir}/task_id)
output_bucket=$(cat ${src_dir}/output_bucket)

# Get S3 paths from the source directory
s3_src_frames=$(cat ${src_dir}/s3_src_frames)
s3_tgt_frames=$(cat ${src_dir}/s3_tgt_frames)
s3_audio=$(cat ${src_dir}/s3_audio)

mkdir -p ${src_dir}/logs

if [ -z $is_anime ]
then
  is_anime="no"
fi
base_name=$(cat ${src_dir}/vid_filename)
image_type=$(cat ${src_dir}/frame_type)
frames=$(cat ${src_dir}/frames)
acodec=$(cat ${src_dir}/acodec)
vfps=$(cat ${src_dir}/vfps)

# AWS Batch job queue and job definition names
BATCH_JOB_QUEUE="video-super-resolution-hybrid-job-queue"
REALESRGAN_JOB_DEFINITION="video-super-resolution-frame-processing"
SWINIR_JOB_DEFINITION="video-super-resolution-frame-processing"
ENCODING_JOB_DEFINITION="video-super-resolution-video-recomposition"

echo "Submitting ${frames} frame processing jobs to AWS Batch..."

# Array to store job IDs
declare -a job_ids

# Determine optimal batch size based on frame count
if [ ${frames} -gt 1000 ]; then
  BATCH_SIZE=20
elif [ ${frames} -gt 500 ]; then
  BATCH_SIZE=15
elif [ ${frames} -gt 200 ]; then
  BATCH_SIZE=10
else
  BATCH_SIZE=5
fi

echo "Using batch size of ${BATCH_SIZE} for ${frames} frames"

# Calculate number of batches
TOTAL_BATCHES=$(( (frames + BATCH_SIZE - 1) / BATCH_SIZE ))
echo "Processing ${frames} frames in ${TOTAL_BATCHES} batches"

# Submit frame processing jobs to AWS Batch in batches
for ((batch=0; batch<${TOTAL_BATCHES}; batch++)); do
  # Calculate start and end frame for this batch
  START_FRAME=$((batch * BATCH_SIZE + 1))
  END_FRAME=$((START_FRAME + BATCH_SIZE - 1))

  # Ensure we don't exceed total frames
  if [ ${END_FRAME} -gt ${frames} ]; then
    END_FRAME=${frames}
  fi

  # Prepare parameters based on whether it's anime or not
  if [ ${is_anime,,} == "yes" ] || [ ${is_anime,,} == "true" ]; then
    JOB_DEFINITION=${REALESRGAN_JOB_DEFINITION}
    JOB_NAME="realesrgan-${task_id}-batch-${batch}"
    MODEL_TYPE="realesrgan"
  else
    JOB_DEFINITION=${SWINIR_JOB_DEFINITION}
    JOB_NAME="swinir-${task_id}-batch-${batch}"
    MODEL_TYPE="swinir"
  fi

  # Create frame range parameter
  FRAME_RANGE="${START_FRAME}-${END_FRAME}"

  # Calculate resource requirements based on batch size and frame characteristics
  # Get video resolution to estimate memory requirements
  VRES=$(cat ${src_dir}/vres)
  WIDTH=$(echo $VRES | cut -d'x' -f1)
  HEIGHT=$(echo $VRES | cut -d'x' -f2)

  # Calculate memory requirements based on resolution and batch size
  # Base memory: 2GB + (width * height * 4 bytes * batch_size) / (1024*1024) MB for frame buffers
  FRAME_MEMORY_MB=$(( WIDTH * HEIGHT * 4 * BATCH_SIZE / 1048576 ))
  TOTAL_MEMORY_MB=$(( 2048 + FRAME_MEMORY_MB ))

  # Ensure minimum memory of 2GB and maximum of 30GB
  if [ ${TOTAL_MEMORY_MB} -lt 2048 ]; then
    TOTAL_MEMORY_MB=2048
  elif [ ${TOTAL_MEMORY_MB} -gt 30720 ]; then
    TOTAL_MEMORY_MB=30720
  fi

  # Calculate vCPUs based on memory (1 vCPU per 4GB of memory, minimum 2, maximum 16)
  VCPUS=$(( TOTAL_MEMORY_MB / 4096 + 2 ))
  if [ ${VCPUS} -lt 2 ]; then
    VCPUS=2
  elif [ ${VCPUS} -gt 16 ]; then
    VCPUS=16
  fi

  echo "Allocating ${VCPUS} vCPUs and ${TOTAL_MEMORY_MB}MB memory for batch ${batch+1}/${TOTAL_BATCHES}"

  # Submit job to AWS Batch with adaptive resource allocation
  job_json=$(aws batch submit-job \
    --job-name ${JOB_NAME} \
    --job-queue ${BATCH_JOB_QUEUE} \
    --job-definition ${JOB_DEFINITION} \
    --parameters "s3_src_frames=${s3_src_frames},s3_tgt_frames=${s3_tgt_frames},base_name=${base_name},frame_range=${FRAME_RANGE},image_type=${image_type},task_id=${task_id},model_type=${MODEL_TYPE},batch_size=${BATCH_SIZE}" \
    --container-overrides "{\"environment\": [{\"name\": \"AWS_REGION\", \"value\": \"us-east-1\"}], \"resourceRequirements\": [{\"type\": \"VCPU\", \"value\": \"${VCPUS}\"}, {\"type\": \"MEMORY\", \"value\": \"${TOTAL_MEMORY_MB}\"}]}")

  # Extract job ID
  job_id=$(echo ${job_json} | jq -r '.jobId')
  job_ids+=(${job_id})

  echo "Submitted batch job ${JOB_NAME} with ID ${job_id} for frames ${START_FRAME}-${END_FRAME} (batch ${batch+1}/${TOTAL_BATCHES})"

  # To avoid throttling, add a small delay between submissions
  sleep 1
done

echo "All frame processing jobs submitted. Waiting for completion..."

# Store job IDs in a file for reference
echo "${job_ids[@]}" > ${src_dir}/batch_job_ids

# Submit a dependent job for video encoding that will run after all frame processing jobs complete
ENCODING_JOB_NAME="encode-${task_id}"

# Create a JSON file with job dependencies
dependencies_json=$(jq -n --arg ids "$(echo ${job_ids[@]} | tr ' ' ',')" '{dependsOn: $ids | split(",") | map({jobId: .})}')
echo ${dependencies_json} > ${src_dir}/dependencies.json

# Submit the encoding job with dependencies
encoding_job_json=$(aws batch submit-job \
  --job-name ${ENCODING_JOB_NAME} \
  --job-queue ${BATCH_JOB_QUEUE} \
  --job-definition ${ENCODING_JOB_DEFINITION} \
  --depends-on "$(cat ${src_dir}/dependencies.json)" \
  --parameters "task_id=${task_id},s3_src_frames=${s3_src_frames},s3_tgt_frames=${s3_tgt_frames},s3_audio=${s3_audio},output_bucket=${output_bucket},vid_filename=${base_name},acodec=${acodec},vfps=${vfps}" \
  --container-overrides '{"environment": [{"name": "AWS_REGION", "value": "us-east-1"}]}')

encoding_job_id=$(echo ${encoding_job_json} | jq -r '.jobId')
echo "Submitted encoding job ${ENCODING_JOB_NAME} with ID ${encoding_job_id}"

# Update DynamoDB with job information
aws dynamodb update-item \
  --table-name VideoSuperResolutionJobs \
  --key '{"JobId": {"S": "'${task_id}'"}}' \
  --update-expression "SET BatchJobIds = :j, Status = :s, UpdatedAt = :t" \
  --expression-attribute-values '{":j": {"SS": ["'$(echo ${job_ids[@]} | tr ' ' '","')'","'${encoding_job_id}'"]}, ":s": {"S": "PROCESSING"}, ":t": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}'

echo "Job information updated in DynamoDB"
echo "processing" > ${src_dir}/pipeline_status
