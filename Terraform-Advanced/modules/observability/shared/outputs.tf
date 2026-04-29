output "observability_summary" {
  description = "Shared observability module summary"
  value = {
    cluster_name       = var.cluster_name
    log_retention_days = var.log_retention_days
  }
}
