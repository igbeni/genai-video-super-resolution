#!/bin/bash
# Script to package Lambda functions for deployment

set -e

# Create directory for zip files if it doesn't exist
mkdir -p lambda_functions/dist

# Package spot_interruption_handler
echo "Packaging spot_interruption_handler..."
cd lambda_functions
npm init -y > /dev/null
npm install aws-sdk --save > /dev/null
mkdir -p dist
zip -r dist/spot_interruption_handler.zip spot_interruption_handler.js node_modules > /dev/null
cd ..

echo "Lambda functions packaged successfully:"
ls -la lambda_functions/dist

echo "Update the Terraform configuration to use the packaged Lambda functions:"
echo "  interruption_handler_zip_path = \"lambda_functions/dist/spot_interruption_handler.zip\""