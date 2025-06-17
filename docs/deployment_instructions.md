# Video Super-Resolution Pipeline Deployment Instructions

## Overview
This document provides detailed instructions for deploying the video super-resolution pipeline using the `deploy_cleanup.sh` script. The pipeline uses S3 for all storage needs, with efficient access patterns and local caching mechanisms for performance.

## Prerequisites
Before deploying the pipeline, ensure you have the following:

1. AWS CLI installed and configured with appropriate credentials
2. AWS ParallelCluster CLI installed (version 3.6.1 or later)
3. Docker installed (for building and testing model containers locally)
4. An AWS account with permissions to create the following resources:
   - EC2 instances (including Spot instances)
   - S3 buckets
   - IAM roles and policies
   - Lambda functions
   - CloudFormation stacks
   - CloudWatch resources
   - AWS Batch resources
5. A VPC with at least one public subnet and one private subnet
6. An SSH key pair for accessing EC2 instances

## Deployment Options

### Option 1: Automated Deployment (Recommended)
The easiest way to deploy the pipeline is to use the provided `deploy_cleanup.sh` script, which automates the entire deployment process.

```bash
./deploy_cleanup.sh deploy \
  --region us-east-1 \
  --account 123456789012 \
  --bucket my-video-super-resolution-bucket \
  --key-pair my-key-pair \
  --vpc-id vpc-12345 \
  --public-subnet subnet-public-12345 \
  --private-subnet subnet-private-12345
```

This will:
1. Create the S3 bucket if it doesn't exist
2. Build and push Docker images for Real-ESRGAN and SwinIR2
3. Prepare and install bootstrap scripts
4. Build a custom AMI for GPU compute nodes
5. Create the ParallelCluster configuration
6. Create the ParallelCluster
7. Deploy the Lambda function via CloudFormation

The deployment process takes approximately 1-2 hours to complete, primarily due to the time required to build the custom AMI and create the ParallelCluster.

### Option 2: Manual Deployment
If you prefer to deploy the components manually, follow these steps:

1. **Create S3 Buckets**:
   - Create an S3 bucket for source videos, processed frames, and final videos
   - Enable versioning and appropriate lifecycle policies
   - Configure server-side encryption

2. **Build and Push Docker Images**:
   ```bash
   cd realesrgan
   ./build_and_push_docker.sh -a [aws account number] -r [aws region name]
   cd ../swinir2
   ./build_and_push_docker.sh -a [aws account number] -r [aws region name]
   ```

3. **Prepare Bootstrap Scripts**:
   ```bash
   cd pcluster/bootstrap
   ./prepare.sh -a [aws account] -r [aws region] -s [s3 source URI] -d [s3 destination URI] -b [s3 bucket name]
   ./install.sh [s3 bucket name]
   ```

4. **Build Custom AMI**:
   ```bash
   cd pcluster
   pcluster build-image --image-id genai-video-super-resolution-base-gpu-ami --image-configuration config/image_config.yaml --region [aws-region]
   ```

5. **Create ParallelCluster Configuration**:
   ```bash
   cd pcluster/config
   ./install.sh -s [s3 bucket] -k [ssh key pair] -v [private subnet] -u [public subnet] -b [gpu script] -d [cpu script] -n [head node script] -g [custom ami] -r [aws region]
   ```

6. **Create ParallelCluster**:
   ```bash
   pcluster create-cluster --cluster-name [cluster name] --cluster-configuration [config file] --region [aws region]
   ```

7. **Deploy Lambda Function**:
   ```bash
   cd lambda
   aws cloudformation create-stack --stack-name [stack name] --template-body file://video_super_resolution.yaml --parameters [parameters] --capabilities CAPABILITY_IAM --region [aws region]
   ```

## Testing the Deployment
After deployment, you can test the pipeline by uploading a video to the source S3 bucket:

1. **Using the UI**:
   ```bash
   cd ui
   docker build -t video-super-resolution-ui .
   docker run -d -e AWS_DEFAULT_REGION=[AWS region] -e AWS_ACCESS_KEY_ID=[aws access key] -e AWS_SECRET_ACCESS_KEY=[aws secret key] -e AWS_SESSION_TOKEN=[aws session token] -e GRADIO_USERNAME=[a unique username] -e GRADIO_PASSWORD=[a unique password] -e S3_BUCKET=[s3 bucket name for storing video content] -e HEAD_NODE=[the headnode EC2 instance ID ] -p 7860:7860 video-super-resolution-ui
   ```
   Then navigate to http://localhost:7860 in your web browser.

2. **Using S3 Directly**:
   - Upload a video file to `s3://[your-bucket]/data/src/[video-type]/[uuid]/`
   - The video type should be either `real` or `anime`
   - The UUID should be a unique identifier (e.g., generated with `uuidgen`)
   - The upscaled video will be available at `s3://[your-bucket]/data/final/[uuid]/`

## Monitoring
The deployment includes comprehensive monitoring capabilities:

1. **CloudWatch Dashboards**:
   - Main dashboard for overall pipeline monitoring
   - Performance dashboard for detailed performance metrics
   - Cost dashboard for cost tracking and optimization

2. **CloudWatch Alarms**:
   - Lambda function errors
   - S3 storage usage
   - EC2 CPU utilization
   - EC2 idle instances
   - Pipeline health

3. **CloudTrail Logging**:
   - API activity logging
   - S3 access logging
   - Compliance reports

## Cost Optimization
The deployment includes several cost optimization features:

1. **EC2 Spot Instances**:
   - Uses EC2 Spot Instances for processing nodes
   - Implements graceful shutdown handling for Spot Instance interruptions
   - Provides fallback to On-Demand instances when necessary

2. **Storage Optimization**:
   - S3 lifecycle policies for intermediate artifacts
   - S3 storage classes (Standard, IA, Glacier)
   - Compression for intermediate files

3. **Resource Management**:
   - Automatic shutdown of idle EC2 instances
   - SageMaker endpoint shutdown after processing
   - Resource leak monitoring

## Cleanup
To clean up all resources created by the deployment:

```bash
./deploy_cleanup.sh cleanup \
  --region us-east-1 \
  --bucket my-video-super-resolution-bucket \
  --cluster-name video-super-resolution \
  --stack-name video-super-resolution-lambda
```

This will:
1. Delete the CloudFormation stack
2. Delete the ParallelCluster
3. Delete the custom AMI and associated snapshots
4. Optionally empty and delete the S3 bucket

## Troubleshooting
If you encounter issues during deployment:

1. **Check CloudWatch Logs**:
   - Lambda function logs
   - EC2 instance logs
   - CloudTrail logs

2. **Check CloudFormation Stack Events**:
   ```bash
   aws cloudformation describe-stack-events --stack-name [stack name] --region [aws region]
   ```

3. **Check ParallelCluster Status**:
   ```bash
   pcluster describe-cluster --cluster-name [cluster name] --region [aws region]
   ```

4. **Common Issues**:
   - Insufficient permissions: Ensure your AWS account has the necessary permissions
   - VPC configuration: Ensure your VPC has the required subnets and security groups
   - Resource limits: Check if you've reached any AWS service limits