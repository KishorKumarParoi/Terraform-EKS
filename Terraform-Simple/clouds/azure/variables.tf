variable "azure_location" {
  description = "Azure location for CI/CD resources"
  type        = string
  default     = "eastus"
}

# Project and environment
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kkp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Add variables for subscription_id, tenant_id, client_id, client_secret via secure storage
