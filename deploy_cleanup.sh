#!/bin/bash
# Video Super-Resolution Pipeline - Deployment and Cleanup Script
# This script provides functionality to deploy and clean up all resources for the
# video super-resolution pipeline solution.

set -e

# Text formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION=""
AWS_ACCOUNT=""
S3_BUCKET=""
SSH_KEY_PAIR=""
VPC_ID=""
PUBLIC_SUBNET_ID=""
PRIVATE_SUBNET_ID=""
CLUSTER_NAME="video-super-resolution"
STACK_NAME="video-super-resolution-lambda"
ACTION=""

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [deploy|cleanup] [options]"
    echo
    echo -e "${BOLD}Actions:${NC}"
    echo "  deploy   - Deploy all resources for the video super-resolution pipeline"
    echo "  cleanup  - Remove all resources created by the deployment"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  -r, --region REGION       AWS region to deploy resources"
    echo "  -a, --account ACCOUNT     AWS account number"
    echo "  -b, --bucket BUCKET       S3 bucket name for storing resources (will be created if it doesn't exist)"
    echo "  -k, --key-pair KEY_PAIR   SSH key pair name for accessing EC2 instances"
    echo "  -v, --vpc-id VPC_ID       VPC ID for deployment"
    echo "  -u, --public-subnet SUBNET_ID  Public subnet ID in the VPC"
    echo "  -p, --private-subnet SUBNET_ID Private subnet ID in the VPC"
    echo "  -c, --cluster-name NAME   Name for the ParallelCluster (default: video-super-resolution)"
    echo "  -s, --stack-name NAME     Name for the CloudFormation stack (default: video-super-resolution-lambda)"
    echo "  -h, --help                Display this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 deploy --region us-east-1 --account 123456789012 --bucket my-bucket --key-pair my-key --vpc-id vpc-12345 --public-subnet subnet-public --private-subnet subnet-private"
    echo "  $0 cleanup --region us-east-1 --cluster-name my-cluster --stack-name my-stack"
}

# Function to log messages
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        *) color=$NC ;;
    esac
    
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${color}${level}${NC}: ${message}"
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "$1 is required but not installed. Please install it and try again."
        exit 1
    fi
}

# Function to check if required parameters are set
check_required_params() {
    local missing_params=0
    
    if [ -z "$AWS_REGION" ]; then
        log "ERROR" "AWS region is required"
        missing_params=1
    fi
    
    if [ "$ACTION" == "deploy" ]; then
        if [ -z "$AWS_ACCOUNT" ]; then
            log "ERROR" "AWS account number is required for deployment"
            missing_params=1
        fi
        
        if [ -z "$S3_BUCKET" ]; then
            log "ERROR" "S3 bucket name is required for deployment"
            missing_params=1
        fi
        
        if [ -z "$SSH_KEY_PAIR" ]; then
            log "ERROR" "SSH key pair name is required for deployment"
            missing_params=1
        fi
        
        if [ -z "$VPC_ID" ]; then
            log "ERROR" "VPC ID is required for deployment"
            missing_params=1
        fi
        
        if [ -z "$PUBLIC_SUBNET_ID" ]; then
            log "ERROR" "Public subnet ID is required for deployment"
            missing_params=1
        fi
        
        if [ -z "$PRIVATE_SUBNET_ID" ]; then
            log "ERROR" "Private subnet ID is required for deployment"
            missing_params=1
        fi
    fi
    
    if [ $missing_params -eq 1 ]; then
        echo
        usage
        exit 1
    fi
}

# Function to create S3 bucket if it doesn't exist
create_s3_bucket() {
    log "INFO" "Checking if S3 bucket exists: $S3_BUCKET"
    
    if aws s3api head-bucket --bucket $S3_BUCKET 2>/dev/null; then
        log "INFO" "S3 bucket already exists: $S3_BUCKET"
    else
        log "INFO" "Creating S3 bucket: $S3_BUCKET"
        aws s3api create-bucket --bucket $S3_BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
        
        # Enable versioning on the bucket
        aws s3api put-bucket-versioning --bucket $S3_BUCKET --versioning-configuration Status=Enabled
        
        log "INFO" "S3 bucket created successfully: $S3_BUCKET"
    fi
}

# Function to build and push Docker images
build_and_push_docker_images() {
    log "INFO" "Building and pushing Docker images"
    
    # Build and push Real-ESRGAN Docker image
    log "INFO" "Building and pushing Real-ESRGAN Docker image"
    cd realesrgan
    ./build_and_push_docker.sh -a $AWS_ACCOUNT -r $AWS_REGION
    cd ..
    
    # Build and push SwinIR2 Docker image
    log "INFO" "Building and pushing SwinIR2 Docker image"
    cd swinir2
    ./build_and_push_docker.sh -a $AWS_ACCOUNT -r $AWS_REGION
    cd ..
    
    log "INFO" "Docker images built and pushed successfully"
}

# Function to prepare and install bootstrap scripts
prepare_and_install_bootstrap() {
    log "INFO" "Preparing and installing bootstrap scripts"
    
    # Define S3 locations
    S3_SOURCE_URI="s3://$S3_BUCKET/data/src"
    S3_DEST_URI="s3://$S3_BUCKET/data/final"
    
    # Prepare bootstrap scripts
    cd pcluster/bootstrap
    ./prepare.sh -a $AWS_ACCOUNT -r $AWS_REGION -s $S3_SOURCE_URI -d $S3_DEST_URI -b $S3_BUCKET
    
    # Install bootstrap scripts
    ./install.sh $S3_BUCKET
    cd ../..
    
    log "INFO" "Bootstrap scripts prepared and installed successfully"
}

# Function to build custom AMI
build_custom_ami() {
    log "INFO" "Building custom AMI for GPU compute nodes"
    
    cd pcluster
    pcluster build-image --image-id genai-video-super-resolution-base-gpu-ami --image-configuration config/image_config.yaml --region $AWS_REGION
    
    # Wait for AMI to be created
    log "INFO" "Waiting for custom AMI to be created (this may take up to 45 minutes)..."
    
    while true; do
        ami_status=$(pcluster describe-image --image-id genai-video-super-resolution-base-gpu-ami --region $AWS_REGION --query "image.imageBuildStatus" --output text)
        
        if [ "$ami_status" == "BUILD_COMPLETE" ]; then
            log "INFO" "Custom AMI created successfully"
            break
        elif [ "$ami_status" == "BUILD_FAILED" ]; then
            log "ERROR" "Custom AMI creation failed"
            exit 1
        fi
        
        log "INFO" "AMI build status: $ami_status"
        sleep 60
    done
    
    # Get AMI ID
    CUSTOM_AMI_ID=$(pcluster describe-image --image-id genai-video-super-resolution-base-gpu-ami --region $AWS_REGION --query "ec2AmiInfo.amiId" --output text)
    log "INFO" "Custom AMI ID: $CUSTOM_AMI_ID"
    cd ..
    
    echo $CUSTOM_AMI_ID
}

# Function to create ParallelCluster configuration
create_cluster_config() {
    local custom_ami_id=$1
    log "INFO" "Creating ParallelCluster configuration"
    
    # Get S3 locations for bootstrap scripts
    GPU_COMPUTE_NODE_SCRIPT="s3://$S3_BUCKET/bootstrap/compute-node-configured.sh"
    CPU_COMPUTE_NODE_SCRIPT="s3://$S3_BUCKET/bootstrap/compute-node-cpu-configured.sh"
    HEAD_NODE_SCRIPT="s3://$S3_BUCKET/bootstrap/head-node-configured.sh"
    
    # Create cluster configuration
    cd pcluster/config
    ./install.sh -s $S3_BUCKET -k $SSH_KEY_PAIR -v $PRIVATE_SUBNET_ID -u $PUBLIC_SUBNET_ID -b $GPU_COMPUTE_NODE_SCRIPT -d $CPU_COMPUTE_NODE_SCRIPT -n $HEAD_NODE_SCRIPT -g $custom_ami_id -r $AWS_REGION
    
    # Get the location of the generated config file
    CONFIG_FILE=$(grep -o "/tmp/cluster-config.yaml" /tmp/cluster-config.yaml 2>/dev/null || echo "/tmp/cluster-config.yaml")
    
    log "INFO" "ParallelCluster configuration created: $CONFIG_FILE"
    cd ../..
    
    echo $CONFIG_FILE
}

# Function to create ParallelCluster
create_parallel_cluster() {
    local config_file=$1
    log "INFO" "Creating ParallelCluster: $CLUSTER_NAME"
    
    pcluster create-cluster --cluster-name $CLUSTER_NAME --cluster-configuration $config_file --region $AWS_REGION
    
    # Wait for cluster to be created
    log "INFO" "Waiting for cluster to be created (this may take up to 30 minutes)..."
    
    while true; do
        cluster_status=$(pcluster describe-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION --query "clusterStatus" --output text)
        
        if [ "$cluster_status" == "CREATE_COMPLETE" ]; then
            log "INFO" "Cluster created successfully"
            break
        elif [ "$cluster_status" == "CREATE_FAILED" ]; then
            log "ERROR" "Cluster creation failed"
            exit 1
        fi
        
        log "INFO" "Cluster status: $cluster_status"
        sleep 60
    done
    
    # Get head node instance ID
    HEAD_NODE_INSTANCE_ID=$(aws ec2 describe-instances --region $AWS_REGION --filters "Name=tag:Name,Values=HeadNode" "Name=tag:parallelcluster:cluster-name,Values=$CLUSTER_NAME" --query "Reservations[0].Instances[0].InstanceId" --output text)
    
    log "INFO" "Head node instance ID: $HEAD_NODE_INSTANCE_ID"
    echo $HEAD_NODE_INSTANCE_ID
}

# Function to deploy Lambda function
deploy_lambda_function() {
    local head_node_instance_id=$1
    log "INFO" "Deploying Lambda function"
    
    # Define S3 locations
    S3_SOURCE_PREFIX="data/src/"
    S3_DEST_URI="s3://$S3_BUCKET/data/final/"
    
    # Deploy CloudFormation stack
    cd lambda
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://video_super_resolution.yaml \
        --parameters \
            ParameterKey=SourceVideoS3BucketName,ParameterValue=$S3_BUCKET \
            ParameterKey=SourceVideoS3PrefixFilter,ParameterValue=$S3_SOURCE_PREFIX \
            ParameterKey=ParallelClusterHeadNodeEC2InstanceId,ParameterValue=$head_node_instance_id \
            ParameterKey=VideoOutputS3Location,ParameterValue=$S3_DEST_URI \
            ParameterKey=SSMResultS3BucketName,ParameterValue=$S3_BUCKET \
        --capabilities CAPABILITY_IAM \
        --region $AWS_REGION
    
    # Wait for stack to be created
    log "INFO" "Waiting for CloudFormation stack to be created..."
    
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION
    
    log "INFO" "Lambda function deployed successfully"
    cd ..
}

# Function to deploy all resources
deploy_resources() {
    log "INFO" "Starting deployment of video super-resolution pipeline"
    
    # Create S3 bucket if it doesn't exist
    create_s3_bucket
    
    # Build and push Docker images
    build_and_push_docker_images
    
    # Prepare and install bootstrap scripts
    prepare_and_install_bootstrap
    
    # Build custom AMI
    CUSTOM_AMI_ID=$(build_custom_ami)
    
    # Create ParallelCluster configuration
    CONFIG_FILE=$(create_cluster_config $CUSTOM_AMI_ID)
    
    # Create ParallelCluster
    HEAD_NODE_INSTANCE_ID=$(create_parallel_cluster $CONFIG_FILE)
    
    # Deploy Lambda function
    deploy_lambda_function $HEAD_NODE_INSTANCE_ID
    
    log "INFO" "Deployment completed successfully"
    log "INFO" "Cluster name: $CLUSTER_NAME"
    log "INFO" "CloudFormation stack name: $STACK_NAME"
    log "INFO" "S3 bucket: $S3_BUCKET"
    log "INFO" "Head node instance ID: $HEAD_NODE_INSTANCE_ID"
}

# Function to clean up all resources
cleanup_resources() {
    log "INFO" "Starting cleanup of video super-resolution pipeline resources"
    
    # Delete CloudFormation stack
    log "INFO" "Deleting CloudFormation stack: $STACK_NAME"
    aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION
    
    # Wait for stack deletion to complete
    log "INFO" "Waiting for CloudFormation stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $AWS_REGION
    
    # Delete ParallelCluster
    log "INFO" "Deleting ParallelCluster: $CLUSTER_NAME"
    pcluster delete-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION
    
    # Wait for cluster deletion to complete
    log "INFO" "Waiting for cluster deletion to complete (this may take some time)..."
    while true; do
        if ! pcluster describe-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION 2>/dev/null; then
            log "INFO" "Cluster deleted successfully"
            break
        fi
        
        log "INFO" "Cluster deletion in progress..."
        sleep 60
    done
    
    # Delete custom AMI
    log "INFO" "Deleting custom AMI"
    AMI_ID=$(aws ec2 describe-images --region $AWS_REGION --owners self --filters "Name=name,Values=genai-video-super-resolution-base-gpu-ami*" --query "Images[0].ImageId" --output text)
    
    if [ "$AMI_ID" != "None" ] && [ ! -z "$AMI_ID" ]; then
        log "INFO" "Deregistering AMI: $AMI_ID"
        aws ec2 deregister-image --image-id $AMI_ID --region $AWS_REGION
        
        # Delete associated snapshots
        SNAPSHOTS=$(aws ec2 describe-snapshots --region $AWS_REGION --owner-ids self --filters "Name=description,Values=*$AMI_ID*" --query "Snapshots[*].SnapshotId" --output text)
        
        for SNAPSHOT in $SNAPSHOTS; do
            log "INFO" "Deleting snapshot: $SNAPSHOT"
            aws ec2 delete-snapshot --snapshot-id $SNAPSHOT --region $AWS_REGION
        done
    else
        log "INFO" "No custom AMI found to delete"
    fi
    
    # Empty and delete S3 bucket if specified
    if [ ! -z "$S3_BUCKET" ]; then
        read -p "Do you want to empty and delete the S3 bucket $S3_BUCKET? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Emptying S3 bucket: $S3_BUCKET"
            aws s3 rm s3://$S3_BUCKET --recursive --region $AWS_REGION
            
            log "INFO" "Deleting S3 bucket: $S3_BUCKET"
            aws s3api delete-bucket --bucket $S3_BUCKET --region $AWS_REGION
        else
            log "INFO" "Skipping S3 bucket deletion"
        fi
    fi
    
    log "INFO" "Cleanup completed successfully"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

ACTION=$1
shift

while [[ $# -gt 0 ]]; do
    key="$1"
    
    case $key in
        -r|--region)
            AWS_REGION="$2"
            shift
            shift
            ;;
        -a|--account)
            AWS_ACCOUNT="$2"
            shift
            shift
            ;;
        -b|--bucket)
            S3_BUCKET="$2"
            shift
            shift
            ;;
        -k|--key-pair)
            SSH_KEY_PAIR="$2"
            shift
            shift
            ;;
        -v|--vpc-id)
            VPC_ID="$2"
            shift
            shift
            ;;
        -u|--public-subnet)
            PUBLIC_SUBNET_ID="$2"
            shift
            shift
            ;;
        -p|--private-subnet)
            PRIVATE_SUBNET_ID="$2"
            shift
            shift
            ;;
        -c|--cluster-name)
            CLUSTER_NAME="$2"
            shift
            shift
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check required commands
check_command aws
check_command pcluster

# Check required parameters
check_required_params

# Execute requested action
case $ACTION in
    deploy)
        deploy_resources
        ;;
    cleanup)
        cleanup_resources
        ;;
    *)
        log "ERROR" "Unknown action: $ACTION"
        usage
        exit 1
        ;;
esac

exit 0