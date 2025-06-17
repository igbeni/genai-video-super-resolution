# GitHub Actions Workflows

This directory contains GitHub Actions workflows for continuous integration and continuous deployment (CI/CD) of the video super-resolution pipeline.

## Overview

The CI/CD pipeline consists of two main workflows:

1. **Test Workflow** (`test.yml`): Runs unit tests and integration tests to ensure code quality.
2. **Build and Deploy Workflow** (`deploy.yml`): Validates, builds, and deploys the infrastructure and application to AWS.

## Test Workflow

The test workflow runs on every push to the main branch and on pull requests. It performs the following steps:

1. Sets up Python environments (3.7, 3.8, 3.9)
2. Installs dependencies
3. Runs unit tests
4. Runs integration tests
5. Uploads coverage reports to Codecov

### Configuration

No additional configuration is required for the test workflow, as it runs in the GitHub Actions environment without accessing external resources.

## Build and Deploy Workflow

The build and deploy workflow runs on pushes to the main branch and can also be triggered manually. It consists of two jobs:

1. **Validate**: Checks Terraform configuration for formatting and validity.
2. **Build and Deploy**: Deploys the infrastructure and application to AWS.

The build and deploy job performs the following steps:

1. Configures AWS credentials
2. Initializes Terraform
3. Plans and applies Terraform configuration
4. Builds Docker images for RealESRGAN and SwinIR
5. Pushes Docker images to Amazon ECR
6. Deploys Lambda functions
7. Runs post-deployment tests

### Configuration

The build and deploy workflow requires the following GitHub secrets to be configured:

- `AWS_ACCESS_KEY_ID`: AWS access key ID with permissions to deploy resources
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key
- `AWS_REGION`: AWS region where resources will be deployed (e.g., `us-east-1`)

To configure these secrets:

1. Go to your GitHub repository
2. Click on "Settings"
3. Click on "Secrets" in the left sidebar
4. Click on "New repository secret"
5. Add each of the required secrets

## Manual Triggers

The build and deploy workflow can be triggered manually using the "workflow_dispatch" event. To trigger the workflow manually:

1. Go to the "Actions" tab in your GitHub repository
2. Select the "Build and Deploy" workflow
3. Click on "Run workflow"
4. Select the branch to run the workflow on
5. Click "Run workflow"

## Troubleshooting

If the workflows fail, check the following:

1. **Test Workflow**:
   - Ensure all dependencies are properly specified in `requirements.txt`
   - Check that tests are correctly implemented and don't rely on external resources

2. **Build and Deploy Workflow**:
   - Verify that AWS credentials are correctly configured as GitHub secrets
   - Ensure Terraform configuration is valid
   - Check that Docker images build successfully
   - Verify that Lambda functions are properly packaged

## Extending the Workflows

To extend the workflows:

1. **Adding Tests**: Add new test files to the `tests/` directory
2. **Adding Terraform Resources**: Update the Terraform configuration in the `terraform/` directory
3. **Adding Docker Images**: Add new Dockerfile and update the build steps in `deploy.yml`
4. **Adding Lambda Functions**: Add new Lambda functions and update the deployment steps in `deploy.yml`