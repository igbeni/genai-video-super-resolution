# AWS Provider Configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.0.0"

  # Uncomment this block to use Terraform Cloud for state management
  # backend "remote" {
  #   organization = "your-organization"
  #   workspaces {
  #     name = "video-super-resolution"
  #   }
  # }
}

provider "aws" {
  region = var.aws_region

  # Uncomment if you need to assume a role
  # assume_role {
  #   role_arn = var.aws_assume_role_arn
  # }

  default_tags {
    tags = var.default_tags
  }
}