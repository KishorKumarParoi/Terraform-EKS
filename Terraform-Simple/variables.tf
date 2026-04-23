# Variable definitions for Terraform configuration
# All values can be overridden via terraform.tfvars or CLI

# AWS Provider Configuration
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

# Project Configuration
variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
  default     = "kkp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# VPC Configuration
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid CIDR notation."
  }
}

# Subnet Configuration
variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 4
    error_message = "Subnet count must be between 1 and 4."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "At least one availability zone must be specified."
  }
}

# EC2/SSH Configuration
variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.ssh_key_name == "" || can(regex("^[a-zA-Z0-9_-]+$", var.ssh_key_name))
    error_message = "SSH key name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Owner   = "DevOps-Team"
    Contact = "devops@example.com"
  }
}
