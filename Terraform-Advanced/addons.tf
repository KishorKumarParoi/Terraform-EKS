################################################################################
# EKS Addons
################################################################################

# EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs.version
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.cluster_name}-ebs-csi"
  }

  depends_on = [
    aws_eks_cluster.kkp,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]
}

# VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }

  depends_on = [aws_eks_cluster.kkp]
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.cluster_name}-coredns"
  }

  depends_on = [aws_eks_cluster.kkp]
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.cluster_name}-kube-proxy"
  }

  depends_on = [aws_eks_cluster.kkp]
}

################################################################################
# VPC CNI IRSA Role
################################################################################

resource "aws_iam_role" "vpc_cni" {
  name_prefix = "vpc-cni-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
            "${replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

################################################################################
# Auto Scaling Configuration
################################################################################

# Get the node group's Auto Scaling Group
data "aws_autoscaling_groups" "node_group" {
  depends_on = [aws_eks_node_group.kkp]

  filter {
    name   = "tag:eks:nodegroup-name"
    values = [aws_eks_node_group.kkp.node_group_name]
  }
}

# Auto Scaling Group Tags for cluster autoscaler discovery
resource "aws_autoscaling_group_tag" "cluster_autoscaler_enabled" {
  count = length(data.aws_autoscaling_groups.node_group.names)

  autoscaling_group_name = data.aws_autoscaling_groups.node_group.names[count.index]

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_discovery" {
  count = length(data.aws_autoscaling_groups.node_group.names)

  autoscaling_group_name = data.aws_autoscaling_groups.node_group.names[count.index]

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

################################################################################
# EBS Encryption KMS Key
################################################################################

resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-ebs"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.cluster_name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}
