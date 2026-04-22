################################################################################
# EKS Addons
################################################################################

# EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs.version
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-ebs-csi"
  }

  timeouts {
    create = "30m"
    delete = "15m"
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
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }

  timeouts {
    create = "30m"
    delete = "15m"
  }

  depends_on = [aws_eks_cluster.kkp]
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-coredns"
  }

  timeouts {
    create = "30m"
    delete = "15m"
  }

  depends_on = [aws_eks_cluster.kkp]
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.kkp.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${var.cluster_name}-kube-proxy"
  }

  timeouts {
    create = "30m"
    delete = "15m"
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

# NOTE: Cluster autoscaler can auto-discover ASGs using the cluster name tag
# that is automatically applied by EKS during node group creation.
#
# EKS automatically tags the ASG with:
#   tag:eks:cluster-name = <cluster_name>
#
# Which allows cluster autoscaler to discover the ASG without explicit tagging.
# The explicit ASG tags below are optional and require a two-step apply:
#   Step 1: terraform apply -target=aws_eks_node_group.kkp
#   Step 2: terraform apply (to apply ASG tags)
#
# For simplicity, we rely on the automatic EKS tagging.

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
