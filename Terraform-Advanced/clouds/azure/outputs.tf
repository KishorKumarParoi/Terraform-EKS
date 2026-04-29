output "azure_platform_summary" {
  description = "Summary of the Azure platform entrypoint"
  value = {
    cluster_name = "multicloud-aks"
    location     = var.azure_location
    cloud        = "azure"
  }
}
