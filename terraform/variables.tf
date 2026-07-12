variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment suffix"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Prefix for resource naming"
  default     = "flask-app"
}

variable "github_repo" {
  type        = string
  description = "The GitHub repository in format 'owner/repo'"
  default     = "Zainabalidev/aws-ecs-container-deployment"
}