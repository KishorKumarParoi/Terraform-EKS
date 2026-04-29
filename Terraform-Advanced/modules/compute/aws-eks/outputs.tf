output "compute_summary" {
  description = "AWS EKS module summary"
  value = {
    cluster_name        = var.cluster_name
    kubernetes_version  = var.kubernetes_version
    node_instance_types = var.node_instance_types
  }
}
