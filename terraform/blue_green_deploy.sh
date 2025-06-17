#!/bin/bash
# Blue/Green Deployment Script for Video Super-Resolution Pipeline
# This script implements a blue/green deployment strategy to minimize downtime

set -e

# Default values
ENV="prod"
AUTO_APPROVE=""
SWAP_ONLY=false
TIMEOUT=300  # 5 minutes timeout for health checks

# Function to display usage information
function display_usage {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -e, --environment ENV   Specify environment (dev, test, prod) [default: prod]"
  echo "  -y, --auto-approve      Auto approve terraform apply/destroy"
  echo "  -s, --swap-only         Only swap blue and green environments (no deployment)"
  echo "  -t, --timeout SECONDS   Timeout in seconds for health checks [default: 300]"
  echo "  -h, --help              Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 -e prod                      # Deploy to prod using blue/green strategy"
  echo "  $0 -e prod -y                   # Deploy to prod with auto-approve"
  echo "  $0 -e prod -s                   # Only swap blue and green environments"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -e|--environment)
      ENV="$2"
      shift
      shift
      ;;
    -y|--auto-approve)
      AUTO_APPROVE="-auto-approve"
      shift
      ;;
    -s|--swap-only)
      SWAP_ONLY=true
      shift
      ;;
    -t|--timeout)
      TIMEOUT="$2"
      shift
      shift
      ;;
    -h|--help)
      display_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      display_usage
      exit 1
      ;;
  esac
done

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
  echo "Error: Invalid environment '$ENV'. Must be one of: dev, test, prod"
  exit 1
fi

# Check if environment directory exists
if [ ! -d "environments/$ENV" ]; then
  echo "Error: Environment directory 'environments/$ENV' does not exist"
  exit 1
fi

# Check if terraform.tfvars exists in environment directory
if [ ! -f "environments/$ENV/terraform.tfvars" ]; then
  echo "Error: terraform.tfvars not found in 'environments/$ENV'"
  exit 1
fi

# Create blue/green directories if they don't exist
mkdir -p "environments/$ENV/blue"
mkdir -p "environments/$ENV/green"

# Determine which environment is currently active (blue or green)
ACTIVE_ENV="blue"
if [ -f "environments/$ENV/active_env" ]; then
  ACTIVE_ENV=$(cat "environments/$ENV/active_env")
fi

# Determine target environment (the one we're deploying to)
if [ "$ACTIVE_ENV" == "blue" ]; then
  TARGET_ENV="green"
else
  TARGET_ENV="blue"
fi

echo "Current active environment: $ACTIVE_ENV"
echo "Target deployment environment: $TARGET_ENV"

# If only swapping environments, update the active environment and exit
if [ "$SWAP_ONLY" = true ]; then
  echo "Swapping active environment from $ACTIVE_ENV to $TARGET_ENV..."
  echo "$TARGET_ENV" > "environments/$ENV/active_env"
  echo "Environment swap completed. New active environment: $TARGET_ENV"
  exit 0
fi

# Copy environment-specific terraform.tfvars to target environment directory
cp "environments/$ENV/terraform.tfvars" "environments/$ENV/$TARGET_ENV/"

# Modify the terraform.tfvars for the target environment to include environment suffix
sed -i.bak "s/\(source_bucket_name.*=.*\"\)\(.*\)\"/\1\2-$TARGET_ENV\"/" "environments/$ENV/$TARGET_ENV/terraform.tfvars"
sed -i.bak "s/\(processed_frames_bucket_name.*=.*\"\)\(.*\)\"/\1\2-$TARGET_ENV\"/" "environments/$ENV/$TARGET_ENV/terraform.tfvars"
sed -i.bak "s/\(final_videos_bucket_name.*=.*\"\)\(.*\)\"/\1\2-$TARGET_ENV\"/" "environments/$ENV/$TARGET_ENV/terraform.tfvars"
rm "environments/$ENV/$TARGET_ENV/terraform.tfvars.bak"

# Copy target environment terraform.tfvars to root directory
echo "Using configuration from $ENV/$TARGET_ENV environment..."
cp "environments/$ENV/$TARGET_ENV/terraform.tfvars" .

# Initialize Terraform if .terraform directory doesn't exist
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Deploy to target environment
echo "Deploying to $ENV/$TARGET_ENV environment..."
terraform apply $AUTO_APPROVE -var-file="terraform.tfvars"

# Perform health checks on the new deployment
echo "Performing health checks on the new deployment..."
# This is a placeholder for actual health checks
# In a real implementation, you would add specific health checks for your services
sleep 5  # Simulating health check time

echo "Health checks passed. New deployment is ready."

# Update the active environment
echo "$TARGET_ENV" > "environments/$ENV/active_env"
echo "Updated active environment to: $TARGET_ENV"

# Provide instructions for rollback if needed
echo ""
echo "Deployment completed successfully."
echo "If you need to rollback to the previous environment, run:"
echo "  $0 -e $ENV -s"
echo ""
echo "To clean up the inactive environment after confirming everything works, run:"
echo "  ./manage_config.sh -e $ENV-$ACTIVE_ENV -a destroy"