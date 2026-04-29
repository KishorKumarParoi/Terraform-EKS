variable "azure_location" {
  description = "Azure region for the secondary platform"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for Azure platform resources"
  type        = string
  default     = "rg-multicloud-terraform"
}

variable "common_tags" {
  description = "Common tags for Azure resources"
  type        = map(string)
  default = {
    Project   = "Multi-Cloud Terraform Advanced"
    ManagedBy = "Terraform"
    Cloud     = "azure"
  }
}
