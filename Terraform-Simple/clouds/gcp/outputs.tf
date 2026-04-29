output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "gke_service_account_email" {
  value = google_service_account.gke_sa.email
}

output "gcs_bucket_name" {
  value = google_storage_bucket.artifacts.name
}
