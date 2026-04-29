output "network_summary" {
  description = "Azure network module summary"
  value = {
    name_prefix   = var.name_prefix
    address_space = var.address_space
    subnets       = var.subnets
  }
}
