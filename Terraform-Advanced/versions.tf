################################################################################
# Remote State Backend Configuration (Optional)
# Uncomment and configure to use S3 remote state for production
################################################################################

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }

# Note: terraform and required_providers are configured in main.tf
# Provider configuration includes default_tags for consistent tagging
