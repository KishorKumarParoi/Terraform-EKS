# Azure provider and Azure AD provider for service principal
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features = {}
}

provider "azuread" {}

# Local tags and naming
locals {
  project_prefix     = var.project_name
  environment_suffix = var.environment
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Resource group for CI/CD artifacts
resource "azurerm_resource_group" "ci" {
  name     = "${local.project_prefix}-ci-${local.environment_suffix}"
  location = var.azure_location
  tags     = local.common_tags
}

# Optional storage account for CI artifacts
resource "azurerm_storage_account" "ci_artifacts" {
  name                     = lower(replace("${local.project_prefix}${var.environment}art", "-", ""))
  resource_group_name      = azurerm_resource_group.ci.name
  location                 = azurerm_resource_group.ci.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false
}

# Azure AD Application + Service Principal for CI
resource "azuread_application" "ci_app" {
  display_name = "${local.project_prefix}-ci-${local.environment_suffix}"
}

resource "azuread_service_principal" "ci_sp" {
  application_id = azuread_application.ci_app.application_id
}

resource "random_password" "sp_password" {
  length  = 32
  special = true
}

resource "azuread_service_principal_password" "ci_sp_pwd" {
  service_principal_id = azuread_service_principal.ci_sp.id
  value                = random_password.sp_password.result
  end_date_relative    = "87600h" # ~10 years
}

output "azure_rg_name" {
  value = azurerm_resource_group.ci.name
}

output "azure_storage_account_name" {
  value = azurerm_storage_account.ci_artifacts.name
}

output "azure_sp_app_id" {
  description = "Service Principal Application ID (use as client_id)"
  value       = azuread_application.ci_app.application_id
}

output "azure_sp_object_id" {
  description = "Service Principal Object ID"
  value       = azuread_service_principal.ci_sp.id
}

output "azure_sp_password" {
  description = "Service Principal password (sensitive)"
  value       = random_password.sp_password.result
  sensitive   = true
}
