# Variables for VPC Endpoints Module

variable "vpc_id" {
  description = "ID of the VPC where endpoints will be created"
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "route_table_ids" {
  description = "List of route table IDs to associate with gateway endpoints"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs where interface endpoints will be created"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
}

variable "processed_frames_bucket_name" {
  description = "Name of the S3 bucket for processed frames"
  type        = string
}

variable "final_videos_bucket_name" {
  description = "Name of the S3 bucket for final videos"
  type        = string
}

variable "access_logs_bucket_name" {
  description = "Name of the S3 bucket for access logs"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for job metadata"
  type        = string
}

variable "name_prefix" {
  description = "Prefix to use for resource names"
  type        = string
  default     = "video-super-resolution"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}