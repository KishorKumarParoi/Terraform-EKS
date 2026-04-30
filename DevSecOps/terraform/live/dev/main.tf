module "aws_base" {
  source       = "../../clouds/aws"
  project_name = var.project_name
  environment  = var.environment
}

module "azure_base" {
  source         = "../../clouds/azure"
  project_name   = var.project_name
  environment    = var.environment
  azure_location = var.azure_location
}

module "gcp_base" {
  source       = "../../clouds/gcp"
  project_name = var.project_name
  environment  = var.environment
  gcp_region   = var.gcp_region
}
