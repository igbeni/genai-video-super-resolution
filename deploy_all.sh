#!/bin/bash
# Video Super-Resolution Pipeline - Comprehensive Deployment Script
# This script provides functionality to deploy all resources for the
# video super-resolution pipeline solution with environment management
# and blue/green deployment support.

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
ENVIRONMENT="dev"
BLUE_GREEN=false
AUTO_APPROVE=""

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
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
    echo "  -e, --environment ENV     Environment to deploy (dev, test, prod) (default: dev)"
    echo "  -g, --blue-green          Use blue/green deployment strategy"
    echo "  -y, --auto-approve        Auto approve terraform apply/destroy"
    echo "  -h, --help                Display this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 --region us-east-1 --account 123456789012 --bucket my-bucket --key-pair my-key --vpc-id vpc-12345 --public-subnet subnet-public --private-subnet subnet-private"
    echo "  $0 --region us-east-1 --account 123456789012 --environment prod --blue-green"
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
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
        log "ERROR" "Environment must be one of: dev, test, prod"
        missing_params=1
    fi
    
    if [ $missing_params -eq 1 ]; then
        echo
        usage
        exit 1
    fi
}

# Function to deploy Terraform infrastructure
deploy_terraform_infrastructure() {
    log "INFO" "Deploying Terraform infrastructure for environment: $ENVIRONMENT"
    
    cd terraform
    
    # Use blue/green deployment if specified
    if [ "$BLUE_GREEN" = true ]; then
        log "INFO" "Using blue/green deployment strategy"
        ./blue_green_deploy.sh -e $ENVIRONMENT $AUTO_APPROVE
    else
        log "INFO" "Using standard deployment"
        ./manage_config.sh -e $ENVIRONMENT -a apply $AUTO_APPROVE
    fi
    
    cd ..
    
    log "INFO" "Terraform infrastructure deployed successfully"
}

# Function to deploy all resources
deploy_all_resources() {
    log "INFO" "Starting comprehensive deployment of video super-resolution pipeline"
    log "INFO" "Environment: $ENVIRONMENT"
    
    # Deploy Terraform infrastructure
    deploy_terraform_infrastructure
    
    # Append environment to resource names
    ENV_SUFFIX="-$ENVIRONMENT"
    CLUSTER_NAME="$CLUSTER_NAME$ENV_SUFFIX"
    STACK_NAME="$STACK_NAME$ENV_SUFFIX"
    
    # If using blue/green deployment, determine active environment
    if [ "$BLUE_GREEN" = true ] && [ -f "terraform/environments/$ENVIRONMENT/active_env" ]; then
        ACTIVE_ENV=$(cat "terraform/environments/$ENVIRONMENT/active_env")
        ENV_SUFFIX="$ENV_SUFFIX-$ACTIVE_ENV"
        CLUSTER_NAME="$CLUSTER_NAME-$ACTIVE_ENV"
        STACK_NAME="$STACK_NAME-$ACTIVE_ENV"
        log "INFO" "Using blue/green environment: $ACTIVE_ENV"
    fi
    
    # Update S3 bucket name with environment suffix if not already included
    if [[ ! "$S3_BUCKET" == *"$ENV_SUFFIX"* ]]; then
        S3_BUCKET="$S3_BUCKET$ENV_SUFFIX"
    fi
    
    log "INFO" "Using S3 bucket: $S3_BUCKET"
    log "INFO" "Using cluster name: $CLUSTER_NAME"
    log "INFO" "Using stack name: $STACK_NAME"
    
    # Call the original deploy_cleanup.sh script with the deploy action
    ./deploy_cleanup.sh deploy \
        --region $AWS_REGION \
        --account $AWS_ACCOUNT \
        --bucket $S3_BUCKET \
        --key-pair $SSH_KEY_PAIR \
        --vpc-id $VPC_ID \
        --public-subnet $PUBLIC_SUBNET_ID \
        --private-subnet $PRIVATE_SUBNET_ID \
        --cluster-name $CLUSTER_NAME \
        --stack-name $STACK_NAME
    
    log "INFO" "Comprehensive deployment completed successfully"
    log "INFO" "Environment: $ENVIRONMENT"
    if [ "$BLUE_GREEN" = true ]; then
        log "INFO" "Blue/Green: $ACTIVE_ENV"
    fi
    log "INFO" "Cluster name: $CLUSTER_NAME"
    log "INFO" "CloudFormation stack name: $STACK_NAME"
    log "INFO" "S3 bucket: $S3_BUCKET"
}

# Parse command line arguments
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
        -e|--environment)
            ENVIRONMENT="$2"
            shift
            shift
            ;;
        -g|--blue-green)
            BLUE_GREEN=true
            shift
            ;;
        -y|--auto-approve)
            AUTO_APPROVE="-y"
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
check_command terraform

# Check required parameters
check_required_params

# Execute deployment
deploy_all_resources

exit 0