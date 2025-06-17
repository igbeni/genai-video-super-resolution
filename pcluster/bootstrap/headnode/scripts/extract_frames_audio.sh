#!/bin/bash
set -e

# Enable error handling
handle_error() {
  local exit_code=$1
  local line_number=$2
  echo "Error occurred at line $line_number with exit code $exit_code"
  echo "error" > ${OUT_DIR}/pipeline_status
  aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value 1 --dimensions task_id=${task_id},phase=extract --metric-name error_count
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

OUT_DIR=$1

S3_SRC=$(cat ${OUT_DIR}/vid_src)
FRAME_TYPE=$(cat ${OUT_DIR}/frame_type)
HEAD_INSTANCE=$(cat ${OUT_DIR}/head_instance)
is_anime=$(cat ${OUT_DIR}/is_anime)
task_id=$(cat ${OUT_DIR}/task_id)
output_bucket=$(cat ${OUT_DIR}/output_bucket)

echo extracting > ${OUT_DIR}/pipeline_status

# Create temporary local directories
mkdir -p ${OUT_DIR}/SRC_FRAMES
mkdir -p ${OUT_DIR}/AUDIO
mkdir -p ${OUT_DIR}/TGT_FRAMES
mkdir -p ${OUT_DIR}/TMP

# Create global cache directories if they don't exist
GLOBAL_CACHE_DIR="/tmp/video_super_resolution_cache"
MODEL_CACHE_DIR="${GLOBAL_CACHE_DIR}/models"
FRAME_CACHE_DIR="${GLOBAL_CACHE_DIR}/frames"
TASK_CACHE_DIR="${GLOBAL_CACHE_DIR}/${task_id}"

mkdir -p ${MODEL_CACHE_DIR}
mkdir -p ${FRAME_CACHE_DIR}
mkdir -p ${TASK_CACHE_DIR}

# Set environment variables for other scripts to use the cache
echo ${GLOBAL_CACHE_DIR} > ${OUT_DIR}/global_cache_dir
echo ${MODEL_CACHE_DIR} > ${OUT_DIR}/model_cache_dir
echo ${FRAME_CACHE_DIR} > ${OUT_DIR}/frame_cache_dir
echo ${TASK_CACHE_DIR} > ${OUT_DIR}/task_cache_dir

# Create a cache manifest file
CACHE_MANIFEST="${GLOBAL_CACHE_DIR}/cache_manifest.json"
if [ ! -f "${CACHE_MANIFEST}" ]; then
    echo '{"models": {}, "frames": {}, "tasks": {}}' > ${CACHE_MANIFEST}
fi

# Create S3 paths for frames and audio
S3_SRC_FRAMES="${output_bucket}/${task_id}/SRC_FRAMES"
S3_AUDIO="${output_bucket}/${task_id}/AUDIO"
S3_TGT_FRAMES="${output_bucket}/${task_id}/TGT_FRAMES"

# Store S3 paths in the OUT_DIR for other scripts to use
echo ${S3_SRC_FRAMES} > ${OUT_DIR}/s3_src_frames
echo ${S3_AUDIO} > ${OUT_DIR}/s3_audio
echo ${S3_TGT_FRAMES} > ${OUT_DIR}/s3_tgt_frames

# Extract the S3 bucket and key from the S3 URL
S3_BUCKET=$(echo ${S3_SRC} | cut -d'/' -f3)
S3_KEY=$(echo ${S3_SRC} | cut -d'/' -f4-)

# Download the source video with retry logic
echo "Downloading source video from S3..."
LOCAL_VIDEO_PATH="${OUT_DIR}/TMP/source_video"
retry_aws_command "aws s3 cp ${S3_SRC} ${LOCAL_VIDEO_PATH} --only-show-errors --endpoint-url https://s3-accelerate.amazonaws.com"

# Extract video information
echo "Extracting video information..."
VID_BASE=$(basename ${S3_KEY})
VID_FILE=${VID_BASE%.*}
VID_EXT=${VID_BASE##*.}

VCODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 ${LOCAL_VIDEO_PATH})
ACODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 ${LOCAL_VIDEO_PATH})
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${LOCAL_VIDEO_PATH})
VRES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ${LOCAL_VIDEO_PATH})
frames=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of default=nokey=1:noprint_wrappers=1 ${LOCAL_VIDEO_PATH})
pad_len=${#frames}
probed_vfps=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate ${LOCAL_VIDEO_PATH})
vfps=$(echo "scale=2;${probed_vfps}" | bc)
vduration=$(ffprobe -v error -show_streams -select_streams v -v quiet ${LOCAL_VIDEO_PATH} | grep "duration=" | cut -d '=' -f 2)
aduration=$(ffprobe -v error -show_streams -select_streams a -v quiet ${LOCAL_VIDEO_PATH} | grep "duration=" | cut -d '=' -f 2)
abitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 ${LOCAL_VIDEO_PATH})

# Store video information
echo ${S3_SRC} > ${OUT_DIR}/source
echo ${VID_FILE} > ${OUT_DIR}/vid_filename
echo ${duration} > ${OUT_DIR}/duration
echo ${vduration} > ${OUT_DIR}/vduration
echo ${aduration} > ${OUT_DIR}/aduration
echo $frames > ${OUT_DIR}/frames
echo $ACODEC > ${OUT_DIR}/acodec
echo $VCODEC > ${OUT_DIR}/vcodec
echo ${vfps} > ${OUT_DIR}/vfps
echo ${VRES} > ${OUT_DIR}/vres
echo ${abitrate} > ${OUT_DIR}/abitrate

if [ ${is_anime,,} == "yes" ] ||  [ ${is_anime,,} == "true" ]
then
	is_anime_param="-a yes"
fi

# Extract frames and audio
echo "Extracting frames and audio..."
SECONDS=0
if [ -z "${ACODEC}" ]
then
  ffmpeg -i ${LOCAL_VIDEO_PATH} -acodec copy -s ${VRES} -fps_mode passthrough ${OUT_DIR}/SRC_FRAMES/${VID_FILE}_%0${pad_len}d.${FRAME_TYPE}
else
  ffmpeg -i ${LOCAL_VIDEO_PATH} -map 0:a ${OUT_DIR}/AUDIO/${VID_FILE}.${ACODEC} -acodec copy -s ${VRES} -fps_mode passthrough ${OUT_DIR}/SRC_FRAMES/${VID_FILE}_%0${pad_len}d.${FRAME_TYPE}
fi
extract_duration=$SECONDS

# Compress extracted frames before uploading to S3
echo "Compressing extracted frames..."
if [ "${FRAME_TYPE}" == "png" ]; then
    # For PNG files, use optipng for lossless compression
    find ${OUT_DIR}/SRC_FRAMES/ -name "*.png" -exec optipng -quiet -o2 {} \;
elif [ "${FRAME_TYPE}" == "jpg" ] || [ "${FRAME_TYPE}" == "jpeg" ]; then
    # For JPEG files, use jpegoptim for compression
    find ${OUT_DIR}/SRC_FRAMES/ -name "*.jpg" -o -name "*.jpeg" -exec jpegoptim --max=90 --quiet {} \;
fi

# Create a compressed tarball of frames in batches to reduce S3 operations
echo "Creating compressed tarballs of frames..."
mkdir -p ${OUT_DIR}/COMPRESSED_FRAMES
mkdir -p ${OUT_DIR}/frame_lists
cd ${OUT_DIR}/SRC_FRAMES/
# Split frames into batches of 100 for better handling
ls -1 | sort -n | split -l 100 - ${OUT_DIR}/frame_lists/batch_
for batch in ${OUT_DIR}/frame_lists/batch_*; do
    batch_name=$(basename $batch)
    tar -czf ${OUT_DIR}/COMPRESSED_FRAMES/${batch_name}.tar.gz -T $batch
done
cd -

# Upload compressed frame tarballs to S3 with optimized settings and retry logic
echo "Uploading compressed frames to S3..."
retry_aws_command "aws s3 cp ${OUT_DIR}/COMPRESSED_FRAMES/ ${S3_SRC_FRAMES}/ --recursive \
    --storage-class STANDARD \
    --only-show-errors \
    --metadata task_id=${task_id},compressed=true \
    --sse AES256 \
    --acl bucket-owner-full-control \
    --jobs 16 \
    --endpoint-url https://s3-accelerate.amazonaws.com"

# Upload audio to S3 if it exists with retry logic
if [ ! -z "${ACODEC}" ]
then
  echo "Uploading audio to S3..."
  retry_aws_command "aws s3 cp ${OUT_DIR}/AUDIO/ ${S3_AUDIO}/ --recursive \
    --storage-class STANDARD \
    --only-show-errors \
    --metadata task_id=${task_id} \
    --sse AES256 \
    --acl bucket-owner-full-control \
    --jobs 8 \
    --endpoint-url https://s3-accelerate.amazonaws.com"
fi

# Clean up temporary files to save disk space
echo "Cleaning up temporary files..."
rm -f ${LOCAL_VIDEO_PATH}

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $extract_duration --dimensions task_id=$task_id,phase=extract --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $extract_duration --dimensions phase=extract --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id --metric-name video_duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --metric-name video_duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value $frames --dimensions task_id=$task_id --metric-name frame_count
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value $frames --metric-name frame_count

ssm_command="sudo su - ec2-user -c '/home/ec2-user/frame-super-resolution-array.sh -s ${OUT_DIR}'"

aws --region us-east-1 ssm send-command --instance-ids "${HEAD_INSTANCE}" \
    --document-name "AWS-RunShellScript" \
    --comment "upscale frames and re-encode" \
    --parameters "{\"commands\":[\"${ssm_command}\"]}" \
    --output text
