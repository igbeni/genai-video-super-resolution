#!/bin/bash
set -e

# Enable error handling
handle_error() {
  local exit_code=$1
  local line_number=$2
  echo "Error occurred at line $line_number with exit code $exit_code"
  echo "error" > ${OUT_DIR}/pipeline_status
  aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Count --value 1 --dimensions task_id=${task_id},phase=encode --metric-name error_count
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
echo encoding > ${OUT_DIR}/pipeline_status

# Get basic parameters
TGT_S3_PREFIX=$(cat ${OUT_DIR}/output_bucket)
task_id=$(cat ${OUT_DIR}/task_id)
frames=$(cat ${OUT_DIR}/frames)
vfps=$(cat ${OUT_DIR}/vfps)
acodec=$(cat ${OUT_DIR}/acodec)
base_name=$(cat ${OUT_DIR}/vid_filename)
image_type=$(cat ${OUT_DIR}/frame_type)
pad_len=${#frames}
abitrate=$(cat ${OUT_DIR}/abitrate)

# Get output format and quality settings (with defaults)
output_format=$(cat ${OUT_DIR}/output_format 2>/dev/null || echo "mp4")
video_quality=$(cat ${OUT_DIR}/video_quality 2>/dev/null || echo "medium")
video_bitrate=$(cat ${OUT_DIR}/video_bitrate 2>/dev/null || echo "0")  # 0 means auto

# Map quality settings to ffmpeg parameters
case $video_quality in
  low)
    quality_params="-preset fast -crf 28"
    ;;
  medium)
    quality_params="-preset medium -crf 23"
    ;;
  high)
    quality_params="-preset slow -crf 18"
    ;;
  ultra)
    quality_params="-preset veryslow -crf 15"
    ;;
  *)
    quality_params="-preset medium -crf 23"  # Default to medium
    ;;
esac

# Add bitrate if specified
if [ "$video_bitrate" != "0" ]; then
  quality_params="$quality_params -b:v $video_bitrate"
fi

# Get S3 paths
s3_tgt_frames=$(cat ${OUT_DIR}/s3_tgt_frames)
s3_audio=$(cat ${OUT_DIR}/s3_audio)

# Create local directories for temporary storage and cache
mkdir -p ${OUT_DIR}/TGT_FRAMES
mkdir -p ${OUT_DIR}/AUDIO
mkdir -p /tmp/encode_cache/${task_id}
mkdir -p /tmp/encode_cache/${task_id}/frames
mkdir -p /tmp/encode_cache/${task_id}/audio

# Create cache manifest files if they don't exist
frames_manifest="/tmp/encode_cache/${task_id}/frames_manifest.txt"
audio_manifest="/tmp/encode_cache/${task_id}/audio_manifest.txt"
touch ${frames_manifest}
touch ${audio_manifest}

# Function to check if a file is in cache and up-to-date
check_cache() {
    local s3_path=$1
    local local_path=$2
    local manifest_file=$3
    local file_name=$(basename ${local_path})
    local cache_path="/tmp/encode_cache/${task_id}/${file_name}"
    local cache_meta="/tmp/encode_cache/${task_id}/${file_name}.meta"

    # Check if file is in cache and metadata exists
    if [ -f "${cache_path}" ] && [ -f "${cache_meta}" ]; then
        local cache_etag=$(cat "${cache_meta}")
        local s3_bucket=$(echo ${s3_path} | cut -d'/' -f3)
        local s3_key=$(echo ${s3_path} | cut -d'/' -f4-)
        local s3_etag=$(aws s3api head-object --bucket ${s3_bucket} --key ${s3_key} --query ETag --output text 2>/dev/null | tr -d '"')

        if [ "${cache_etag}" = "${s3_etag}" ]; then
            # File is in cache and up-to-date
            cp "${cache_path}" "${local_path}"
            echo "${local_path}" >> ${manifest_file}
            return 0
        fi
    fi

    # File is not in cache or outdated
    return 1
}

# Function to update cache with a new file
update_cache() {
    local s3_path=$1
    local local_path=$2
    local file_name=$(basename ${local_path})
    local cache_path="/tmp/encode_cache/${task_id}/${file_name}"
    local cache_meta="/tmp/encode_cache/${task_id}/${file_name}.meta"

    cp "${local_path}" "${cache_path}"
    local s3_bucket=$(echo ${s3_path} | cut -d'/' -f3)
    local s3_key=$(echo ${s3_path} | cut -d'/' -f4-)
    local s3_etag=$(aws s3api head-object --bucket ${s3_bucket} --key ${s3_key} --query ETag --output text 2>/dev/null | tr -d '"')
    echo "${s3_etag}" > "${cache_meta}"
}

# Download processed frames from S3 with caching
echo "Downloading processed frames from S3 with caching..."
# First, try to use cached frames
cached_frames=0
total_frames=${frames}
for i in $(seq 1 ${total_frames}); do
    frame_num=$(printf "%0${pad_len}d" $i)
    frame_name="${base_name}_${frame_num}.${image_type}"
    s3_frame_path="${s3_tgt_frames}/${frame_name}"
    local_frame_path="${OUT_DIR}/TGT_FRAMES/${frame_name}"

    if check_cache "${s3_frame_path}" "${local_frame_path}" "${frames_manifest}"; then
        cached_frames=$((cached_frames + 1))
    fi
done

# Download any frames not in cache
if [ ${cached_frames} -lt ${total_frames} ]; then
    echo "Downloading ${total_frames} - ${cached_frames} frames from S3..."
    # Create a list of files to download (those not in the manifest)
    for i in $(seq 1 ${total_frames}); do
        frame_num=$(printf "%0${pad_len}d" $i)
        frame_name="${base_name}_${frame_num}.${image_type}"
        local_frame_path="${OUT_DIR}/TGT_FRAMES/${frame_name}"

        if ! grep -q "${local_frame_path}" "${frames_manifest}"; then
            s3_frame_path="${s3_tgt_frames}/${frame_name}"
            aws s3 cp "${s3_frame_path}" "${local_frame_path}" \
                --only-show-errors \
                --request-payer requester \
                --quiet \
                --endpoint-url https://s3-accelerate.amazonaws.com

            # Update cache
            update_cache "${s3_frame_path}" "${local_frame_path}"
            echo "${local_frame_path}" >> ${frames_manifest}
        fi
    done
else
    echo "All frames found in cache."
fi

# Download audio from S3 if it exists with caching
if [ ! -z "${acodec}" ]
then
    echo "Checking for cached audio..."
    audio_file="${base_name}.${acodec}"
    s3_audio_path="${s3_audio}/${audio_file}"
    local_audio_path="${OUT_DIR}/AUDIO/${audio_file}"

    if check_cache "${s3_audio_path}" "${local_audio_path}" "${audio_manifest}"; then
        echo "Using cached audio file."
    else
        echo "Downloading audio from S3..."
        aws s3 cp "${s3_audio_path}" "${local_audio_path}" \
            --only-show-errors \
            --request-payer requester \
            --quiet \
            --endpoint-url https://s3-accelerate.amazonaws.com

        # Update cache
        update_cache "${s3_audio_path}" "${local_audio_path}"
        echo "${local_audio_path}" >> ${audio_manifest}
    fi
fi

SECONDS=0

# Determine output file extension based on format
output_file="${OUT_DIR}/${base_name}_final_upscaled.${output_format}"

# Select video codec based on output format
case $output_format in
  mp4)
    video_codec="libx264"
    pixel_format="yuv420p"
    ;;
  webm)
    video_codec="libvpx-vp9"
    pixel_format="yuv420p"
    ;;
  mkv)
    video_codec="libx264"
    pixel_format="yuv420p"
    ;;
  mov)
    video_codec="libx264"
    pixel_format="yuv420p"
    ;;
  *)
    video_codec="libx264"
    pixel_format="yuv420p"
    output_format="mp4"
    output_file="${OUT_DIR}/${base_name}_final_upscaled.mp4"
    ;;
esac

echo "Encoding video with format: ${output_format}, codec: ${video_codec}, quality: ${video_quality}"

# Check if audio codec is found, if not do not encode audio because the original video does not have any audios
if [ -z "${acodec}" ]
then
  ffmpeg -framerate ${vfps} -i ${OUT_DIR}/TGT_FRAMES/${base_name}_%0${pad_len}d.${image_type} \
    -shortest \
    -c:v ${video_codec} \
    -pix_fmt ${pixel_format} \
    ${quality_params} \
    ${output_file}
else
  ffmpeg -framerate ${vfps} -i ${OUT_DIR}/TGT_FRAMES/${base_name}_%0${pad_len}d.${image_type} \
    -i ${OUT_DIR}/AUDIO/${base_name}.${acodec} \
    -c:a copy -b:a ${abitrate} \
    -shortest \
    -c:v ${video_codec} \
    -pix_fmt ${pixel_format} \
    ${quality_params} \
    ${output_file}
fi

duration=$SECONDS

aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions task_id=$task_id,phase=encode --metric-name duration
aws --region us-east-1 cloudwatch put-metric-data --namespace SuperRes/tasks --unit Seconds --value $duration --dimensions phase=encode --metric-name duration

output_s3_key=${TGT_S3_PREFIX}/${task_id}/${base_name}_final_upscaled.${output_format}

# Compress the final video if it's not already in a compressed format
echo "Preparing final video for upload..."
compressed_output="${output_file}.compressed"

# Check if the video format is already well-compressed
if [[ "${output_format}" == "mp4" || "${output_format}" == "webm" ]]; then
    # For already compressed formats, check if we can optimize further
    if command -v ffmpeg-normalize >/dev/null 2>&1; then
        echo "Optimizing video for network transfer..."
        # Use ffmpeg to optimize the video for network transfer without significant quality loss
        ffmpeg -i ${output_file} -c:v libx264 -preset faster -crf 23 -c:a aac -b:a 128k -movflags +faststart ${compressed_output}
        if [ $? -eq 0 ] && [ -f ${compressed_output} ]; then
            orig_size=$(stat -c %s ${output_file})
            new_size=$(stat -c %s ${compressed_output})
            reduction=$(( (orig_size - new_size) * 100 / orig_size ))

            if [ ${reduction} -gt 10 ]; then
                echo "Compression reduced file size by ${reduction}% (${orig_size} -> ${new_size} bytes)"
                mv ${compressed_output} ${output_file}
            else
                echo "Compression only reduced file size by ${reduction}%, using original file"
                rm -f ${compressed_output}
            fi
        else
            echo "Compression failed, using original file"
            rm -f ${compressed_output}
        fi
    else
        echo "ffmpeg-normalize not available, using original file"
    fi
else
    echo "Format ${output_format} is not optimal for network transfer, converting to mp4..."
    # Convert to mp4 with good compression
    ffmpeg -i ${output_file} -c:v libx264 -preset faster -crf 23 -c:a aac -b:a 128k -movflags +faststart ${compressed_output}.mp4
    if [ $? -eq 0 ] && [ -f ${compressed_output}.mp4 ]; then
        orig_size=$(stat -c %s ${output_file})
        new_size=$(stat -c %s ${compressed_output}.mp4)
        reduction=$(( (orig_size - new_size) * 100 / orig_size ))

        if [ ${reduction} -gt 10 ]; then
            echo "Conversion to mp4 reduced file size by ${reduction}% (${orig_size} -> ${new_size} bytes)"
            # Keep original file but upload the compressed version
            cp ${compressed_output}.mp4 ${output_file}.mp4
            output_file="${output_file}.mp4"
            output_format="mp4"
        else
            echo "Conversion only reduced file size by ${reduction}%, using original file"
            rm -f ${compressed_output}.mp4
        fi
    else
        echo "Conversion failed, using original file"
        rm -f ${compressed_output}.mp4
    fi
fi

# Upload final video to S3 using multipart upload for better performance and reliability
echo "Uploading final video to S3 using multipart upload..."
# For large files, use multipart upload with appropriate part size and concurrency
# The minimum part size for multipart uploads is 5MB
# Using 25MB parts for optimal performance with S3 Transfer Acceleration
retry_aws_command "aws s3 cp ${output_file} ${output_s3_key} \
    --storage-class STANDARD \
    --only-show-errors \
    --metadata task_id=${task_id},format=${output_format},quality=${video_quality} \
    --expected-size $(stat -c %s ${output_file}) \
    --multipart-chunk-size 25MB \
    --sse AES256 \
    --acl bucket-owner-full-control \
    --endpoint-url https://s3-accelerate.amazonaws.com"
echo ${output_s3_key} > ${OUT_DIR}/output_s3_key

# Update DynamoDB with completion status
echo "Updating DynamoDB with completion status..."
aws dynamodb update-item \
  --table-name VideoSuperResolutionJobs \
  --key '{"JobId": {"S": "'${task_id}'"}}' \
  --update-expression "SET Status = :s, OutputS3Key = :o, UpdatedAt = :t, VideoFormat = :f, VideoQuality = :q" \
  --expression-attribute-values '{":s": {"S": "COMPLETED"}, ":o": {"S": "'${output_s3_key}'"}, ":t": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}, ":f": {"S": "'${output_format}'"}, ":q": {"S": "'${video_quality}'"}}'

# Clean up local files
echo "Cleaning up local files..."
rm -rf ${OUT_DIR}/TGT_FRAMES
rm -rf ${OUT_DIR}/AUDIO
rm -f ${output_file}

echo uploaded > ${OUT_DIR}/pipeline_status
