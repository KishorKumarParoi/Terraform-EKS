output "compute_summary" {
  description = "Azure AKS module summary"
  value = {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    node_vm_size       = var.node_vm_size
  }
}
