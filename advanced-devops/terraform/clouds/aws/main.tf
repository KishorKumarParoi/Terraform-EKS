module "global_tags" {
  source       = "../../modules/global-tags"
  project_name = var.project_name
  environment  = var.environment
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-${var.environment}-artifacts-demo"
  tags   = module.global_tags.tags
}
