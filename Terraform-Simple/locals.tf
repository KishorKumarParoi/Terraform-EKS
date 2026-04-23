# Local values for centralized configuration
# This file defines reusable values across the Terraform configuration

locals {
  # Common project prefix for naming resources
  project_prefix = var.project_name

  # Environment-based naming convention
  environment_suffix = var.environment

  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "Terraform"
    CreatedAt   = timestamp()
    ManagedBy   = "Infrastructure-as-Code"
  }

  # VPC Configuration
  vpc_config = {
    cidr_block = var.vpc_cidr_block
    name       = "${local.project_prefix}-vpc-${local.environment_suffix}"
  }

  # Subnet Configuration
  subnet_config = {
    count              = var.subnet_count
    availability_zones = var.availability_zones
    name_prefix        = "${local.project_prefix}-subnet"
  }

  # Internet Gateway Configuration
  igw_config = {
    name = "${local.project_prefix}-igw-${local.environment_suffix}"
  }

  # Route Table Configuration
  route_table_config = {
    name = "${local.project_prefix}-route-table-${local.environment_suffix}"
  }

  # AWS Region
  aws_region = var.aws_region

  # Resource naming convention function
  resource_name = "${local.project_prefix}-${local.environment_suffix}"
}
