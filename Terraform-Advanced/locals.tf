################################################################################
# Local Values
# Computed values used throughout the Terraform configuration
################################################################################

locals {
  # Cluster name with environment prefix (if needed)
  cluster_id = aws_eks_cluster.kkp.id

  # OIDC provider for IRSA
  oidc_provider_arn = aws_iam_openid_connect_provider.eks_oidc.arn
  oidc_provider_url = replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")

  # Common name prefix for all resources
  name_prefix = "${var.cluster_name}-"

  # Availability zones
  availability_zones = data.aws_availability_zones.available.names

  # AWS Account ID
  account_id = data.aws_caller_identity.current.account_id

  # Subnet tags for load balancer service discovery
  subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  # Common tags to be applied to all resources
  tags = merge(
    var.common_tags,
    {
      "Cluster"   = var.cluster_name
      "CreatedAt" = timestamp()
    }
  )
}
