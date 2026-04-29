variable "aws_region" {
  description = "AWS region for the primary platform"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name used across AWS platform resources"
  type        = string
  default     = "multi-cloud-aws"
}

variable "common_tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default = {
    Project   = "Multi-Cloud Terraform Advanced"
    ManagedBy = "Terraform"
    Cloud     = "aws"
  }
}
