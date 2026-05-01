variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used as prefix for resource names"
  type        = string
  default     = "notifications-poc"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "api_stage_name" {
  description = "API Gateway deployment stage name"
  type        = string
  default     = "v1"
}
