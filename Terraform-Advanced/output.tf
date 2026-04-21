################################################################################
# EKS Cluster Outputs
################################################################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.kkp.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.kkp.name
}

output "cluster_endpoint" {
  description = "Endpoint for your EKS Kubernetes API server"
  value       = aws_eks_cluster.kkp.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.kkp.version
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.kkp.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, null)
}

output "cluster_oidc_issuer_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = try(aws_iam_openid_connect_provider.eks_oidc.arn, null)
}

################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.kkp_vpc.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.kkp_vpc.cidr_block
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.kkp_subnet[*].id
}

output "subnet_azs" {
  description = "List of availability zones for subnets"
  value       = aws_subnet.kkp_subnet[*].availability_zone
}

################################################################################
# Node Group Outputs
################################################################################

output "node_group_id" {
  description = "The ID of the EKS node group"
  value       = aws_eks_node_group.kkp.id
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.kkp.arn
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.kkp.node_group_name
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.kkp.status
}

output "node_group_resources" {
  description = "Resources associated with the EKS node group"
  value       = aws_eks_node_group.kkp.resources
}

################################################################################
# IAM Role Outputs
################################################################################

output "cluster_iam_role_arn" {
  description = "ARN of IAM role for EKS cluster"
  value       = aws_iam_role.kkp_cluster_role.arn
}

output "node_iam_role_arn" {
  description = "ARN of IAM role for EKS node group"
  value       = aws_iam_role.kkp_node_group_role.arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "vpc_cni_role_arn" {
  description = "ARN of IAM role for VPC CNI"
  value       = aws_iam_role.vpc_cni.arn
}

################################################################################
# Security Group Outputs
################################################################################

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_security_group.kkp_cluster_sg.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the worker nodes"
  value       = aws_security_group.kkp_node_sg.id
}

################################################################################
# KMS Key Outputs
################################################################################

output "eks_kms_key_id" {
  description = "The KMS key ID used for EKS cluster encryption"
  value       = aws_kms_key.eks.id
}

output "eks_kms_key_arn" {
  description = "The KMS key ARN used for EKS cluster encryption"
  value       = aws_kms_key.eks.arn
}

output "ebs_kms_key_id" {
  description = "The KMS key ID for EBS volume encryption"
  value       = aws_kms_key.ebs.id
}

output "ebs_kms_key_arn" {
  description = "The KMS key ARN for EBS volume encryption"
  value       = aws_kms_key.ebs.arn
}

################################################################################
# CloudWatch Logs Outputs
################################################################################

output "cluster_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.cluster_logs.name
}

output "cluster_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.cluster_logs.arn
}

################################################################################
# Add-ons Outputs
################################################################################

output "ebs_csi_addon_id" {
  description = "ID of the EBS CSI driver addon"
  value       = try(aws_eks_addon.ebs_csi.id, null)
}

output "vpc_cni_addon_id" {
  description = "ID of the VPC CNI addon"
  value       = try(aws_eks_addon.vpc_cni.id, null)
}

output "coredns_addon_id" {
  description = "ID of the CoreDNS addon"
  value       = try(aws_eks_addon.coredns.id, null)
}

output "kube_proxy_addon_id" {
  description = "ID of the kube-proxy addon"
  value       = try(aws_eks_addon.kube_proxy.id, null)
}

################################################################################
# kubectl Configuration
################################################################################

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.kkp.name}"
}

output "kubectl_context" {
  description = "Kubectl context for this cluster"
  value       = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${aws_eks_cluster.kkp.name}"
}

################################################################################
# Summary Outputs
################################################################################

output "cluster_summary" {
  description = "Summary of cluster configuration"
  value = {
    cluster_name       = aws_eks_cluster.kkp.name
    cluster_endpoint   = aws_eks_cluster.kkp.endpoint
    kubernetes_version = aws_eks_cluster.kkp.version
    vpc_id             = aws_vpc.kkp_vpc.id
    subnet_ids         = aws_subnet.kkp_subnet[*].id
    node_group_name    = aws_eks_node_group.kkp.node_group_name
    region             = var.aws_region
  }
}
