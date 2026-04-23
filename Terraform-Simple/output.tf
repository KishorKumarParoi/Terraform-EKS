# Output values for Terraform configuration
# These outputs provide important resource information for reference and other modules

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = local.vpc_config.name
}

# Subnet Outputs
output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.main[*].id
}

output "subnet_cidr_blocks" {
  description = "List of subnet CIDR blocks"
  value       = aws_subnet.main[*].cidr_block
}

output "subnet_availability_zones" {
  description = "List of subnet availability zones"
  value       = aws_subnet.main[*].availability_zone
}

# Internet Gateway Outputs
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Route Table Outputs
output "route_table_id" {
  description = "ID of the Route Table"
  value       = aws_route_table.main.id
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the main security group"
  value       = aws_security_group.main.id
}

output "security_group_name" {
  description = "Name of the main security group"
  value       = aws_security_group.main.name
}

# Network ACL Output
output "network_acl_id" {
  description = "ID of the Network ACL"
  value       = aws_network_acl.main.id
}

# Local Configuration Outputs
output "project_name" {
  description = "Project name used for resource naming"
  value       = local.project_prefix
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region used for deployment"
  value       = local.aws_region
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
  sensitive   = false
}
