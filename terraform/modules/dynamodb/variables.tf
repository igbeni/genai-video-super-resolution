# Variables for DynamoDB Module

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for job metadata"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}