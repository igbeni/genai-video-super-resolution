# API Interfaces and Integration Points

## Overview
This document describes the API interfaces and integration points in the video super-resolution pipeline. The pipeline uses a combination of Lambda functions, S3 events, SNS topics, and DynamoDB to orchestrate the video processing workflow.

## API Interfaces

### 1. Presigned URL Generator API

#### Description
The Presigned URL Generator API provides a secure way to upload videos to the S3 bucket. It generates a presigned URL that allows temporary, authenticated access to upload a file to a specific location in the S3 bucket.

#### Endpoint
This API is implemented as a Lambda function (`presigned_url_generator.py`) and can be exposed through API Gateway.

#### Request Parameters
- **fileName** (required): The name of the file to be uploaded
- **contentType** (optional): The content type of the file (default: application/octet-stream)
- **expiration** (optional): The expiration time of the presigned URL in seconds (default: 3600, min: 300, max: 604800)

#### Request Example
```json
{
  "fileName": "my-video.mp4",
  "contentType": "video/mp4",
  "expiration": 3600
}
```

#### Response Example
```json
{
  "url": "https://my-bucket.s3.amazonaws.com/uploads/my-video.mp4?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...",
  "key": "uploads/my-video.mp4",
  "bucket": "my-bucket",
  "expiresIn": 3600
}
```

#### Error Responses
- **400 Bad Request**: Missing required parameters
- **500 Internal Server Error**: Error generating presigned URL

## Integration Points

### 1. Pipeline Trigger

#### Description
The Pipeline Trigger is a Lambda function (`pipeline_trigger.py`) that initiates the video super-resolution pipeline when a new video is uploaded to the S3 bucket. It validates the uploaded file, generates a unique job ID, stores job metadata in DynamoDB, and publishes a message to an SNS topic to start frame extraction.

#### Trigger
This function is triggered by S3 events when a new object is created in the source bucket.

#### Event Example
```json
{
  "Records": [
    {
      "s3": {
        "bucket": {
          "name": "my-bucket"
        },
        "object": {
          "key": "data/src/real/12345678-1234-1234-1234-123456789012/my-video.mp4"
        }
      }
    }
  ]
}
```

#### Process Flow
1. The function is triggered when a new video is uploaded to the S3 bucket
2. It validates that the uploaded file is a video (based on file extension)
3. It generates a unique job ID
4. It retrieves video metadata from S3
5. It creates job metadata and stores it in DynamoDB
6. It publishes a message to an SNS topic to start frame extraction

#### Output
The function publishes a message to an SNS topic with the following information:
```json
{
  "jobId": "12345678-1234-1234-1234-123456789012",
  "videoName": "my-video.mp4",
  "sourceBucket": "my-bucket",
  "sourceKey": "data/src/real/12345678-1234-1234-1234-123456789012/my-video.mp4"
}
```

### 2. Frame Extraction

#### Description
The Frame Extraction process is triggered by the SNS message published by the Pipeline Trigger. It downloads the video from S3, extracts frames and audio, and uploads them back to S3.

#### Trigger
This process is triggered by an SNS message published by the Pipeline Trigger.

#### Process Flow
1. The process receives an SNS message with job details
2. It downloads the video from S3
3. It extracts frames and audio from the video
4. It uploads the frames and audio to S3
5. It updates the job metadata in DynamoDB
6. It publishes a message to an SNS topic to start frame processing

### 3. Frame Processing

#### Description
The Frame Processing process is triggered by the SNS message published by the Frame Extraction process. It processes each frame using the AI models (Real-ESRGAN or SwinIR) and uploads the processed frames back to S3.

#### Trigger
This process is triggered by an SNS message published by the Frame Extraction process.

#### Process Flow
1. The process receives an SNS message with job details
2. It downloads the frames from S3
3. It processes each frame using the AI models
4. It uploads the processed frames to S3
5. It updates the job metadata in DynamoDB
6. It publishes a message to an SNS topic to start video recomposition

### 4. Video Recomposition

#### Description
The Video Recomposition process is triggered by the SNS message published by the Frame Processing process. It downloads the processed frames and audio from S3, recomposes the video, and uploads the final video back to S3.

#### Trigger
This process is triggered by an SNS message published by the Frame Processing process.

#### Process Flow
1. The process receives an SNS message with job details
2. It downloads the processed frames and audio from S3
3. It recomposes the video
4. It uploads the final video to S3
5. It updates the job metadata in DynamoDB
6. It publishes a message to an SNS topic to notify completion

## Data Storage

### DynamoDB Table
The pipeline uses a DynamoDB table to store job metadata. The table has the following schema:

#### Primary Key
- **JobId** (String): The unique identifier for the job

#### Attributes
- **VideoName** (String): The name of the video
- **SourceBucket** (String): The S3 bucket where the source video is stored
- **SourceKey** (String): The S3 key of the source video
- **ProcessedBucket** (String): The S3 bucket where the processed frames are stored
- **FinalBucket** (String): The S3 bucket where the final video is stored
- **ContentLength** (Number): The size of the source video in bytes
- **ContentType** (String): The content type of the source video
- **Status** (String): The status of the job (INITIATED, EXTRACTING, PROCESSING, RECOMPOSING, COMPLETED, FAILED)
- **CreatedAt** (String): The timestamp when the job was created
- **UpdatedAt** (String): The timestamp when the job was last updated
- **Frames** (Map): Information about the frames
  - **Total** (Number): The total number of frames in the video
  - **Extracted** (Number): The number of frames that have been extracted
  - **Processed** (Number): The number of frames that have been processed

## S3 Bucket Structure

### Source Bucket
- **data/src/[video-type]/[uuid]/**: Source videos
  - **video-type**: Either "real" or "anime"
  - **uuid**: A unique identifier for the job

### Processed Bucket
- **jobs/[job-id]/frames/**: Extracted frames
- **jobs/[job-id]/processed_frames/**: Processed frames
- **jobs/[job-id]/audio/**: Extracted audio
- **jobs/[job-id]/checkpoints/**: Checkpoints for interrupted jobs

### Final Bucket
- **data/final/[uuid]/**: Final videos