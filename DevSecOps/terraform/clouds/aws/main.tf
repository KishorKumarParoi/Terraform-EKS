resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-${var.environment}-devsecops-artifacts"
}
