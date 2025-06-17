# Environment Configuration Management

This directory contains environment-specific configurations for the Video Super-Resolution Pipeline. The configurations are organized into separate directories for each environment:

- `dev/`: Development environment configuration
- `test/`: Testing environment configuration
- `prod/`: Production environment configuration

Each environment can also have blue/green deployment configurations:

- `dev/blue/`: Blue deployment for development environment
- `dev/green/`: Green deployment for development environment
- `test/blue/`: Blue deployment for testing environment
- `test/green/`: Green deployment for testing environment
- `prod/blue/`: Blue deployment for production environment
- `prod/green/`: Green deployment for production environment

## Configuration Files

Each environment directory contains a `terraform.tfvars` file with environment-specific variable values. These files override the default values defined in the root `variables.tf` file.

## Using the Configuration Management System

The Video Super-Resolution Pipeline includes a configuration management script (`manage_config.sh`) that simplifies working with different environments. This script handles copying the appropriate environment-specific configuration file and executing Terraform commands.

### Basic Usage

```bash
# Navigate to the terraform directory
cd terraform

# Display help information
./manage_config.sh --help

# Plan changes for the dev environment
./manage_config.sh -e dev -a plan

# Apply changes to the test environment
./manage_config.sh -e test -a apply

# Destroy the prod environment with auto-approve
./manage_config.sh -e prod -a destroy -y
```

### Command Line Options

- `-e, --environment ENV`: Specify environment (dev, test, prod) [default: dev]
- `-a, --action ACTION`: Specify action (plan, apply, destroy) [default: apply]
- `-y, --auto-approve`: Auto approve terraform apply/destroy
- `-h, --help`: Display help message

## Adding a New Environment

To add a new environment:

1. Create a new directory under `environments/` with the environment name
2. Create a `terraform.tfvars` file in the new directory with environment-specific values
3. Use the configuration management script with the new environment name

Example:
```bash
mkdir -p environments/staging
cp environments/test/terraform.tfvars environments/staging/terraform.tfvars
# Edit environments/staging/terraform.tfvars with staging-specific values
./manage_config.sh -e staging -a plan
```

## Environment-Specific Configurations

### Development Environment (`dev/`)

The development environment is configured with:
- Minimal resources to reduce costs
- Shorter retention periods for intermediate files
- Lower auto-scaling capacity

### Testing Environment (`test/`)

The testing environment is configured with:
- Versioning enabled to track changes
- Medium retention periods for intermediate files
- More memory for Lambda functions to handle test cases
- Medium auto-scaling capacity

### Production Environment (`prod/`)

The production environment is configured with:
- Versioning enabled to ensure data integrity
- Standard retention periods for intermediate files
- Longer timeouts and more memory for Lambda functions
- Larger and multiple instances for SageMaker
- Higher minimum capacity and full maximum capacity for auto-scaling
- Lower target CPU utilization for better responsiveness

## Blue/Green Deployment Strategy

The Video Super-Resolution Pipeline supports a blue/green deployment strategy to minimize downtime and risk during deployments. This strategy involves maintaining two identical production environments, called Blue and Green. At any time, only one of these environments is live and serving production traffic.

### How Blue/Green Deployment Works

1. Initially, the Blue environment is active and serving all traffic
2. When a new deployment is needed, changes are applied to the Green environment
3. After the Green environment is deployed and passes health checks, traffic is switched from Blue to Green
4. The Green environment becomes the new active environment
5. If issues are detected, traffic can be quickly switched back to the Blue environment

### Using the Blue/Green Deployment Script

The project includes a blue/green deployment script (`blue_green_deploy.sh`) that automates this process:

```bash
# Navigate to the terraform directory
cd terraform

# Display help information
./blue_green_deploy.sh --help

# Deploy to production using blue/green strategy
./blue_green_deploy.sh -e prod

# Deploy with auto-approve
./blue_green_deploy.sh -e prod -y

# Rollback by swapping to the previous environment
./blue_green_deploy.sh -e prod -s
```

### Command Line Options

- `-e, --environment ENV`: Specify environment (dev, test, prod) [default: prod]
- `-y, --auto-approve`: Auto approve terraform apply
- `-s, --swap-only`: Only swap blue and green environments (no deployment)
- `-t, --timeout SECONDS`: Timeout in seconds for health checks [default: 300]
- `-h, --help`: Display help message

### Benefits of Blue/Green Deployment

- **Minimal Downtime**: The switch between environments is nearly instantaneous
- **Easy Rollback**: If issues are detected, you can quickly revert to the previous environment
- **Reduced Risk**: The new environment is fully tested before receiving production traffic
- **Separate Resources**: Blue and green environments use separate resources, preventing conflicts
