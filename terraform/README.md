# Terraform Configuration for Video Super-Resolution Pipeline

This directory contains Terraform configuration for deploying the infrastructure required for the Video Super-Resolution Pipeline on AWS. The implementation is based on the Hyperscale Media Super Resolution architecture but with S3-only storage (no FSx for Lustre) and managed with Infrastructure as Code (Terraform).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (version >= 1.0.0)
- AWS CLI configured with appropriate credentials
- Sufficient permissions to create the required AWS resources

## Directory Structure

```
terraform/
├── modules/                  # Reusable Terraform modules
│   ├── s3/                   # S3 buckets module
│   │   ├── main.tf           # S3 bucket resources
│   │   ├── variables.tf      # Input variables for the module
│   │   └── outputs.tf        # Output values from the module
│   ├── iam/                  # IAM roles and policies module
│   │   ├── main.tf           # IAM resources
│   │   ├── variables.tf      # Input variables for the module
│   │   └── outputs.tf        # Output values from the module
│   ├── lambda/               # Lambda functions module
│   │   ├── main.tf           # Lambda functions and SNS topics
│   │   ├── variables.tf      # Input variables for the module
│   │   └── outputs.tf        # Output values from the module
│   └── ... (future modules)
├── main.tf                   # Main configuration file
├── variables.tf              # Input variables
├── outputs.tf                # Output values
├── providers.tf              # Provider configuration
└── terraform.tfvars.example  # Example variable values
```

## Getting Started

1. Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` to set your desired values, especially the S3 bucket names which must be globally unique.

3. Initialize Terraform:

```bash
terraform init
```

4. Plan the deployment:

```bash
terraform plan
```

5. Apply the configuration:

```bash
terraform apply
```

6. When you're done, you can destroy the resources:

```bash
terraform destroy
```

## Current Resources

Currently, this Terraform configuration creates:

- S3 buckets for:
  - Source videos
  - Processed frames (intermediate artifacts)
  - Final videos (output)

All buckets are configured with:
- Server-side encryption
- Optional versioning
- Lifecycle rules for intermediate artifacts (automatic cleanup)

- IAM roles and policies with least privilege for:
  - Lambda functions for pipeline orchestration
  - EC2 instances for processing nodes
  - AWS Batch service and job execution
  - CloudWatch logging

All IAM resources follow the principle of least privilege, granting only the permissions necessary for each component to function.

- Lambda functions for pipeline orchestration:
  - Pipeline trigger (triggered by S3 events when new videos are uploaded)
  - Frame extraction (creates jobs to extract frames from videos)
  - Frame processing (creates jobs to process frames with AI models)
  - Video recomposition (creates jobs to recompose processed frames into videos)
  - Completion notification (sends notifications when processing is complete)

- SNS topics for event-driven communication:
  - Extract frames topic
  - Processing topic
  - Recomposition topic
  - Notification topic
  - Email notification topic

## Future Additions

Future updates will add:
- EC2 Spot Fleet configurations for processing nodes
- AWS Batch compute environments and job queues
- CloudWatch dashboards, alarms, and log groups
- SNS topics for notifications
- Step Functions workflow for orchestration
- SQS queues for job coordination

## Notes

- S3 bucket names must be globally unique
- The configuration uses default values that can be overridden in `terraform.tfvars`
- All resources are tagged with the values specified in `default_tags`
