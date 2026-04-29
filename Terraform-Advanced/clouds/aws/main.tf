provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

locals {
  intended_modules = [
    "network",
    "compute",
    "security",
    "observability",
  ]
}

# Wire these modules in when you turn the scaffold into a live AWS stack:
# - ../../modules/network/aws
# - ../../modules/compute/aws-eks
# - ../../modules/security/shared
# - ../../modules/observability/shared
