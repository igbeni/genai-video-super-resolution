#!/bin/bash
# Script to format all Terraform files in the repository

set -e

echo "Formatting Terraform files..."

# Change to the terraform directory if the script is run from the project root
if [ -d "terraform" ] && [ ! -f "main.tf" ]; then
  cd terraform
fi

# Run terraform fmt to format all Terraform files
terraform fmt -recursive

echo "Terraform formatting completed successfully."