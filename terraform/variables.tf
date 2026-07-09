variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}


variable "container_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "ECS task CPU"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "ECS task memory"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of tasks"
  type        = number
  default     = 2
}

variable "min_count" {
  description = "Min tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Max tasks for autoscaling"
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Log level"
  type        = string
  default     = "INFO"
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "1.0.0"
}

variable "gunicorn_workers" {
  description = "Number of Gunicorn workers"
  type        = string
  default     = "auto"
}