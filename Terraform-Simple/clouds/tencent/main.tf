# Tencent Cloud provider skeleton
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentyunstack/tencentcloud"
      version = "~> 1.0"
    }
  }
}

provider "tencentcloud" {
  region = var.tencent_region
}

# Add Tencent Cloud resources here
