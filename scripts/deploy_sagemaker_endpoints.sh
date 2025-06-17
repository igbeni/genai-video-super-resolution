#!/bin/bash
# Script to deploy AI models to SageMaker endpoints

set -e

# Default values
AWS_REGION=${AWS_REGION:-"us-east-1"}
REALESRGAN_IMAGE_NAME="video-super-resolution-realesrgan"
SWINIR_IMAGE_NAME="video-super-resolution-swinir"
TERRAFORM_VAR_FILE="terraform.tfvars"

# Display usage information
function usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --region REGION       AWS region (default: $AWS_REGION)"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "This script builds and pushes Docker images for Real-ESRGAN and SwinIR models,"
    echo "then deploys them as SageMaker endpoints using Terraform."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "=== Deploying AI models to SageMaker endpoints in region: $AWS_REGION ==="

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get AWS account ID. Make sure you're authenticated with AWS CLI."
    exit 1
fi

# ECR repository URIs
REALESRGAN_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REALESRGAN_IMAGE_NAME}"
SWINIR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SWINIR_IMAGE_NAME}"

# Create ECR repositories if they don't exist
echo "=== Creating ECR repositories if they don't exist ==="
aws ecr describe-repositories --repository-names ${REALESRGAN_IMAGE_NAME} --region ${AWS_REGION} || \
    aws ecr create-repository --repository-name ${REALESRGAN_IMAGE_NAME} --region ${AWS_REGION}

aws ecr describe-repositories --repository-names ${SWINIR_IMAGE_NAME} --region ${AWS_REGION} || \
    aws ecr create-repository --repository-name ${SWINIR_IMAGE_NAME} --region ${AWS_REGION}

# Login to ECR
echo "=== Logging in to ECR ==="
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build and push Real-ESRGAN Docker image
echo "=== Building and pushing Real-ESRGAN Docker image ==="
cd realesrgan
docker build -t ${REALESRGAN_IMAGE_NAME}:latest -f Dockerfile.realesrgan.gpu --build-arg AWS_REGION=${AWS_REGION} .
docker tag ${REALESRGAN_IMAGE_NAME}:latest ${REALESRGAN_REPO_URI}:latest
docker push ${REALESRGAN_REPO_URI}:latest
cd ..

# Build and push SwinIR Docker image
echo "=== Building and pushing SwinIR Docker image ==="
cd swinir2
docker build -t ${SWINIR_IMAGE_NAME}:latest -f Dockerfile.swinir2.gpu --build-arg AWS_REGION=${AWS_REGION} .
docker tag ${SWINIR_IMAGE_NAME}:latest ${SWINIR_REPO_URI}:latest
docker push ${SWINIR_REPO_URI}:latest
cd ..

# Create or update Terraform variables file with ECR image URIs
echo "=== Updating Terraform variables with ECR image URIs ==="
if [ ! -f "terraform/${TERRAFORM_VAR_FILE}" ]; then
    cp terraform/terraform.tfvars.example terraform/${TERRAFORM_VAR_FILE}
fi

# Update or add the SageMaker variables to the Terraform variables file
grep -q "realesrgan_image_uri" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'realesrgan_image_uri = ""' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "swinir_image_uri" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'swinir_image_uri = ""' >> terraform/${TERRAFORM_VAR_FILE}

# Replace the image URIs in the Terraform variables file
sed -i.bak "s|realesrgan_image_uri = \".*\"|realesrgan_image_uri = \"${REALESRGAN_REPO_URI}:latest\"|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|swinir_image_uri = \".*\"|swinir_image_uri = \"${SWINIR_REPO_URI}:latest\"|g" terraform/${TERRAFORM_VAR_FILE}
rm -f terraform/${TERRAFORM_VAR_FILE}.bak

# Deploy with Terraform
echo "=== Deploying SageMaker endpoints with Terraform ==="
cd terraform
terraform init
terraform plan -var-file=${TERRAFORM_VAR_FILE}
terraform apply -var-file=${TERRAFORM_VAR_FILE} -auto-approve

# Get the SageMaker endpoint names
REALESRGAN_ENDPOINT=$(terraform output -raw realesrgan_endpoint_name 2>/dev/null || echo "Not available")
SWINIR_ENDPOINT=$(terraform output -raw swinir_endpoint_name 2>/dev/null || echo "Not available")

echo "=== Deployment complete ==="
echo "Real-ESRGAN endpoint: ${REALESRGAN_ENDPOINT}"
echo "SwinIR endpoint: ${SWINIR_ENDPOINT}"
echo ""
echo "To use these endpoints, you can invoke them with the AWS SDK or CLI:"
echo "aws sagemaker-runtime invoke-endpoint --endpoint-name ${REALESRGAN_ENDPOINT} --content-type application/json --body '{\"input_file_path\":\"s3://bucket/input.png\",\"output_file_path\":\"s3://bucket/output.png\",\"job_id\":\"123\",\"batch_id\":\"1\"}' output.json"
echo ""
echo "For more information, see the documentation in docs/sagemaker_deployment.md"