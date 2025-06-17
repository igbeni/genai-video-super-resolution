#!/bin/bash
# Script to deploy AI models to EC2 instances with Docker

set -e

# Default values
AWS_REGION=${AWS_REGION:-"us-east-1"}
REALESRGAN_IMAGE_NAME="video-super-resolution-realesrgan"
SWINIR_IMAGE_NAME="video-super-resolution-swinir"
TERRAFORM_VAR_FILE="terraform.tfvars"
INSTANCE_TYPE="g4dn.xlarge"
SPOT_PRICE="0.5"
MIN_INSTANCES=1
MAX_INSTANCES=4

# Display usage information
function usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --region REGION       AWS region (default: $AWS_REGION)"
    echo "  -t, --instance-type TYPE  EC2 instance type (default: $INSTANCE_TYPE)"
    echo "  -p, --spot-price PRICE    Maximum spot price (default: $SPOT_PRICE)"
    echo "  --min-instances COUNT     Minimum number of instances (default: $MIN_INSTANCES)"
    echo "  --max-instances COUNT     Maximum number of instances (default: $MAX_INSTANCES)"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "This script builds and pushes Docker images for Real-ESRGAN and SwinIR models,"
    echo "then deploys them on EC2 instances using Terraform."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -t|--instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        -p|--spot-price)
            SPOT_PRICE="$2"
            shift 2
            ;;
        --min-instances)
            MIN_INSTANCES="$2"
            shift 2
            ;;
        --max-instances)
            MAX_INSTANCES="$2"
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

echo "=== Deploying AI models to EC2 instances with Docker in region: $AWS_REGION ==="
echo "Instance type: $INSTANCE_TYPE"
echo "Spot price: $SPOT_PRICE"
echo "Min instances: $MIN_INSTANCES"
echo "Max instances: $MAX_INSTANCES"

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

# Create or update Terraform variables file with ECR image URIs and EC2 configuration
echo "=== Updating Terraform variables with ECR image URIs and EC2 configuration ==="
if [ ! -f "terraform/${TERRAFORM_VAR_FILE}" ]; then
    cp terraform/terraform.tfvars.example terraform/${TERRAFORM_VAR_FILE}
fi

# Update or add the EC2 Spot Fleet variables to the Terraform variables file
grep -q "ec2_spot_instance_type" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'ec2_spot_instance_type = ""' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "ec2_spot_price" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'ec2_spot_price = ""' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "ec2_min_instances" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'ec2_min_instances = 1' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "ec2_max_instances" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'ec2_max_instances = 4' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "realesrgan_ecr_image_uri" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'realesrgan_ecr_image_uri = ""' >> terraform/${TERRAFORM_VAR_FILE}

grep -q "swinir_ecr_image_uri" terraform/${TERRAFORM_VAR_FILE} || \
    echo 'swinir_ecr_image_uri = ""' >> terraform/${TERRAFORM_VAR_FILE}

# Replace the values in the Terraform variables file
sed -i.bak "s|ec2_spot_instance_type = \".*\"|ec2_spot_instance_type = \"${INSTANCE_TYPE}\"|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|ec2_spot_price = \".*\"|ec2_spot_price = \"${SPOT_PRICE}\"|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|ec2_min_instances = .*|ec2_min_instances = ${MIN_INSTANCES}|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|ec2_max_instances = .*|ec2_max_instances = ${MAX_INSTANCES}|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|realesrgan_ecr_image_uri = \".*\"|realesrgan_ecr_image_uri = \"${REALESRGAN_REPO_URI}:latest\"|g" terraform/${TERRAFORM_VAR_FILE}
sed -i.bak "s|swinir_ecr_image_uri = \".*\"|swinir_ecr_image_uri = \"${SWINIR_REPO_URI}:latest\"|g" terraform/${TERRAFORM_VAR_FILE}
rm -f terraform/${TERRAFORM_VAR_FILE}.bak

# Create user-data script for EC2 instances
echo "=== Creating user-data script for EC2 instances ==="
cat > terraform/files/user-data.sh << 'EOF'
#!/bin/bash
# User data script for EC2 instances

# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install AWS CLI
apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REALESRGAN_REPO_URI%/*}

# Pull Docker images
docker pull ${REALESRGAN_REPO_URI}:latest
docker pull ${SWINIR_REPO_URI}:latest

# Create docker-compose.yml
mkdir -p /opt/video-super-resolution
cat > /opt/video-super-resolution/docker-compose.yml << 'EOFINNER'
version: '3'
services:
  realesrgan:
    image: ${REALESRGAN_REPO_URI}:latest
    restart: always
    ports:
      - "8080:8080"
    environment:
      - AWS_REGION=${AWS_REGION}
    volumes:
      - /tmp:/tmp
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  swinir:
    image: ${SWINIR_REPO_URI}:latest
    restart: always
    ports:
      - "8081:8080"
    environment:
      - AWS_REGION=${AWS_REGION}
    volumes:
      - /tmp:/tmp
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
EOFINNER

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start the containers
cd /opt/video-super-resolution
docker-compose up -d
EOF

# Replace placeholders in user-data script
sed -i.bak "s|\${AWS_REGION}|${AWS_REGION}|g" terraform/files/user-data.sh
sed -i.bak "s|\${REALESRGAN_REPO_URI}|${REALESRGAN_REPO_URI}|g" terraform/files/user-data.sh
sed -i.bak "s|\${SWINIR_REPO_URI}|${SWINIR_REPO_URI}|g" terraform/files/user-data.sh
rm -f terraform/files/user-data.sh.bak

# Deploy with Terraform
echo "=== Deploying EC2 instances with Terraform ==="
cd terraform
terraform init
terraform plan -var-file=${TERRAFORM_VAR_FILE}
terraform apply -var-file=${TERRAFORM_VAR_FILE} -auto-approve

# Get the EC2 instance IDs and public IPs
INSTANCE_IDS=$(terraform output -json ec2_instance_ids 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "Not available")
INSTANCE_IPS=$(terraform output -json ec2_instance_public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "Not available")

echo "=== Deployment complete ==="
echo "EC2 instance IDs: ${INSTANCE_IDS}"
echo "EC2 instance public IPs: ${INSTANCE_IPS}"
echo ""
echo "The AI models are now running on EC2 instances with Docker."
echo "Real-ESRGAN API is available at: http://<EC2_PUBLIC_IP>:8080"
echo "SwinIR API is available at: http://<EC2_PUBLIC_IP>:8081"
echo ""
echo "For more information, see the documentation in docs/ec2_docker_deployment.md"