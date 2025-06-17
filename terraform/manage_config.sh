#!/bin/bash
# Configuration Management Script for Video Super-Resolution Pipeline
# This script helps manage environment-specific configurations

set -e

# Default values
ENV="dev"
ACTION="apply"
AUTO_APPROVE=""

# Function to display usage information
function display_usage {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -e, --environment ENV   Specify environment (dev, test, prod) [default: dev]"
  echo "  -a, --action ACTION     Specify action (plan, apply, destroy) [default: apply]"
  echo "  -y, --auto-approve      Auto approve terraform apply/destroy"
  echo "  -h, --help              Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 -e dev -a plan                # Plan changes for dev environment"
  echo "  $0 -e test -a apply              # Apply changes to test environment"
  echo "  $0 -e prod -a destroy -y         # Destroy prod environment with auto-approve"
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
    -a|--action)
      ACTION="$2"
      shift
      shift
      ;;
    -y|--auto-approve)
      AUTO_APPROVE="-auto-approve"
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

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
  echo "Error: Invalid action '$ACTION'. Must be one of: plan, apply, destroy"
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

# Copy environment-specific terraform.tfvars to root directory
echo "Using configuration from $ENV environment..."
cp "environments/$ENV/terraform.tfvars" .

# Initialize Terraform if .terraform directory doesn't exist
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Execute the specified action
echo "Executing terraform $ACTION for $ENV environment..."
case $ACTION in
  plan)
    terraform plan -var-file="terraform.tfvars"
    ;;
  apply)
    terraform apply $AUTO_APPROVE -var-file="terraform.tfvars"
    ;;
  destroy)
    terraform destroy $AUTO_APPROVE -var-file="terraform.tfvars"
    ;;
esac

echo "Configuration management for $ENV environment completed successfully."