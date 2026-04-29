# GCP provider and basic GKE + GCS resources
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

locals {
  project_prefix     = var.project_name
  environment_suffix = var.environment
}

# Service account for GKE nodes/workloads
resource "google_service_account" "gke_sa" {
  account_id   = "${local.project_prefix}-gke-sa"
  display_name = "GKE service account for ${local.project_prefix}"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.gcp_region
  initial_node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    service_account = google_service_account.gke_sa.email
  }
}

# Storage bucket for artifacts/persistent storage
resource "google_storage_bucket" "artifacts" {
  name          = "${local.project_prefix}-${var.environment}-artifacts"
  location      = var.gcp_region
  force_destroy = true
}

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
