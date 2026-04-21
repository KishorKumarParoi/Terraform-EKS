output "cluster_id" {
  value = aws_eks_cluster.kkp.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.kkp.endpoint
}

output "cluster_ca_certificate" {
  value     = aws_eks_cluster.kkp.certificate_authority[0].data
  sensitive = true
}

output "node_group_id" {
  value = aws_eks_node_group.kkp.id
}

output "vpc_id" {
  value = aws_vpc.kkp_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.kkp_subnet[*].id
}

output "ebs_csi_driver_role_arn" {
  value = aws_iam_role.ebs_csi_driver.arn
}

output "cluster_oidc_issuer" {
  value = aws_eks_cluster.kkp.identity[0].oidc[0].issuer
}
