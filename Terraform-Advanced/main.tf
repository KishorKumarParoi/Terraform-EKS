################################################################################
# AWS Provider Configuration
################################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

provider "tls" {
  # TLS provider for OIDC certificate verification and certificate operations
  # Used to retrieve and verify OIDC provider certificates
}

################################################################################
# Data Sources
################################################################################

# Current AWS Account Information
# Used to get account ID for IAM policy resources and OIDC provider configuration
data "aws_caller_identity" "current" {}

# Get information about the AWS partition (for ARN construction)
# Useful for GovCloud, China regions, or standard AWS regions
data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest addon versions compatible with EKS cluster
data "aws_eks_addon_version" "ebs" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.kkp.version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.kkp.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.kkp.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.kkp.version
  most_recent        = true
}

# Get latest EKS AMI for nodes
data "aws_ami" "eks_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.kkp.version}-*"]
  }
}

################################################################################
# VPC and Networking
################################################################################

resource "aws_vpc" "kkp_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "kkp_igw" {
  vpc_id = aws_vpc.kkp_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }

  depends_on = [aws_vpc.kkp_vpc]
}

# Public Subnets
resource "aws_subnet" "kkp_subnet" {
  count = var.subnet_count

  vpc_id                  = aws_vpc.kkp_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kkp_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  depends_on = [aws_vpc.kkp_vpc]
}

# Route Table for Public Subnets
resource "aws_route_table" "kkp_route_table" {
  vpc_id = aws_vpc.kkp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kkp_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-rt"
  }

  depends_on = [aws_internet_gateway.kkp_igw]
}

# Route Table Association
resource "aws_route_table_association" "kkp_association" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.kkp_subnet[count.index].id
  route_table_id = aws_route_table.kkp_route_table.id
}

################################################################################
# Security Groups
################################################################################

# EKS Cluster Security Group
resource "aws_security_group" "kkp_cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = aws_vpc.kkp_vpc.id
  description = "Security group for ${var.cluster_name} EKS cluster"

  # Allow outbound HTTPS for pod communication
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Separate ingress rule to avoid circular dependency
resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kkp_node_sg.id
  security_group_id        = aws_security_group.kkp_cluster_sg.id
  description              = "Allow worker nodes to communicate with cluster API"
}

# EKS Worker Node Security Group
resource "aws_security_group" "kkp_node_sg" {
  name_prefix = "${var.cluster_name}-node-"
  vpc_id      = aws_vpc.kkp_vpc.id
  description = "Security group for ${var.cluster_name} worker nodes"

  # Allow all inbound traffic within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.kkp_vpc.cidr_block]
    description = "Allow all traffic within VPC"
  }

  # Allow inbound from cluster security group (for metrics, etc.)
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.kkp_cluster_sg.id]
    description     = "Allow traffic from cluster control plane"
  }

  # Allow SSH access (conditional)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidr
      description = "Allow SSH access"
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "kkp" {
  name     = var.cluster_name
  role_arn = aws_iam_role.kkp_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.kkp_subnet[*].id
    security_group_ids      = [aws_security_group.kkp_cluster_sg.id]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Enable control plane logging
  enabled_cluster_log_types = var.cluster_log_types

  # Encryption
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Tags
  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.kkp_cluster_role_policy,
    aws_cloudwatch_log_group.cluster_logs,
  ]
}

# CloudWatch Log Group for EKS Cluster Logs
resource "aws_cloudwatch_log_group" "cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"] # https://github.com/aws/aws-iam-authenticator/blob/master/cert.pem thumbprint
  url             = aws_eks_cluster.kkp.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

################################################################################
# KMS Key for EKS Encryption
################################################################################

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-key"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

# Note: EBS CSI Driver IAM role, addon configuration, and VPC CNI role are defined in addons.tf

################################################################################
# EKS Node Group
################################################################################

resource "aws_eks_node_group" "kkp" {
  cluster_name    = aws_eks_cluster.kkp.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.kkp_node_group_role.arn
  subnet_ids      = aws_subnet.kkp_subnet[*].id
  version         = var.kubernetes_version

  scaling_config {
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
    desired_size = var.node_group_desired_size
  }

  instance_types = var.enable_cost_optimization && var.use_smaller_instance_types ? ["t3.small"] : var.node_instance_types
  disk_size      = var.node_disk_size

  # Cost optimization: Use Spot instances for 60-70% savings on EC2 costs
  capacity_type = (var.enable_cost_optimization || var.enable_spot_instances) ? "SPOT" : "ON_DEMAND"

  # Dynamic SSH access configuration
  dynamic "remote_access" {
    for_each = var.ssh_key_name != "" ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.kkp_node_sg.id]
    }
  }

  # Taints for blue-green deployment
  dynamic "taint" {
    for_each = var.node_group_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = var.node_group_labels

  tags = {
    Name = "${var.cluster_name}-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.kkp_node_group_role_policy,
    aws_iam_role_policy_attachment.kkp_node_group_cni_policy,
    aws_iam_role_policy_attachment.kkp_node_group_registry_policy,
    aws_iam_role_policy_attachment.kkp_node_group_ebs_policy,
  ]

  # Ignore changes to desired_size for auto-scaling
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
################################################################################
# IAM Roles and Policies
################################################################################

# Cluster Role
resource "aws_iam_role" "kkp_cluster_role" {
  name_prefix = "${var.cluster_name}-cluster-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "kkp_cluster_role_policy" {
  role       = aws_iam_role.kkp_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "kkp_cluster_vpc_resource_controller" {
  role       = aws_iam_role.kkp_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# Node Group Role
resource "aws_iam_role" "kkp_node_group_role" {
  name_prefix = "${var.cluster_name}-node-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "kkp_node_group_role_policy" {
  role       = aws_iam_role.kkp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "kkp_node_group_cni_policy" {
  role       = aws_iam_role.kkp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "kkp_node_group_registry_policy" {
  role       = aws_iam_role.kkp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "kkp_node_group_ebs_policy" {
  role       = aws_iam_role.kkp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "kkp_node_group_ssm_policy" {
  role       = aws_iam_role.kkp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EBS CSI Driver IAM Role with IRSA
resource "aws_iam_role" "ebs_csi_driver" {
  name_prefix = "ebs-csi-driver-"

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
            "${replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_eks_cluster.kkp.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-ebs-csi-driver"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}
