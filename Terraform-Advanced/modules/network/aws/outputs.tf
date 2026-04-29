output "network_summary" {
  description = "AWS network module summary"
  value = {
    name_prefix        = var.name_prefix
    vpc_cidr_block     = var.vpc_cidr_block
    subnet_count       = var.subnet_count
    availability_zones = var.availability_zones
  }
}
