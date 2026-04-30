variable "project_name" {
  type    = string
  default = "devsecops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "gcp_project" {
  type    = string
  default = "replace-me"
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}
