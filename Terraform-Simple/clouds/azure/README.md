Azure CI/CD placeholder for Terraform-Simple.

This folder should contain Azure resources used for CI/CD integration (e.g., service principal, resource group for artifact storage, pipelines configuration). Example pipeline is located at `../pipelines/azure-pipelines.yml`.

Suggested content to add:
- `main.tf` with `azurerm` provider and a `resource_group` for CI artifacts
- `variables.tf` for Azure subscription, tenant and service principal secrets (use secure storage)
- Documentation for configuring Azure DevOps service connection or GitHub Actions with Azure credentials
