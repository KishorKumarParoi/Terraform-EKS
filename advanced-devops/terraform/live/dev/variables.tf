variable "project_name" {
  type        = string
  default     = "advanced-devops"
  description = "Global project name"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "azure_location" {
  type        = string
  default     = "eastus"
  description = "Azure location"
}

variable "gcp_project" {
  type        = string
  default     = "replace-with-project-id"
  description = "GCP project"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "GCP region"
}
