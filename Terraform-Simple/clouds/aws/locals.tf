locals {
  project_prefix     = var.project_name
  environment_suffix = var.environment

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "Terraform"
    ManagedBy   = "Infrastructure-as-Code"
  }

  vpc_config = {
    cidr_block = var.vpc_cidr_block
    name       = "${local.project_prefix}-vpc-${local.environment_suffix}"
  }

  subnet_config = {
    count              = var.subnet_count
    availability_zones = var.availability_zones
    name_prefix        = "${local.project_prefix}-subnet"
  }

  igw_config = {
    name = "${local.project_prefix}-igw-${local.environment_suffix}"
  }

  route_table_config = {
    name = "${local.project_prefix}-route-table-${local.environment_suffix}"
  }

  aws_region    = var.aws_region
  resource_name = "${local.project_prefix}-${local.environment_suffix}"
}
