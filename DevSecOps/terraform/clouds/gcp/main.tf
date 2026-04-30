resource "google_storage_bucket" "artifacts" {
  name          = "${var.project_name}-${var.environment}-artifacts"
  location      = var.gcp_region
  force_destroy = true
}
