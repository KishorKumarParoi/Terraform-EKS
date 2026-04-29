provider "azurerm" {
  features {}
}

locals {
  intended_modules = [
    "network",
    "compute",
    "security",
    "observability",
  ]
}

# Wire these modules in when you turn the scaffold into a live Azure stack:
# - ../../modules/network/azure
# - ../../modules/compute/azure-aks
# - ../../modules/security/shared
# - ../../modules/observability/shared
