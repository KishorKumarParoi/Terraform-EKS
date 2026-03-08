provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "kkp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "kkp-vpc"
  }
}

resource "aws_subnet" "kkp_subnet" {
  count = 2
  vpc_id                  = aws_vpc.kkp_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kkp_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "kkp-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "kkp_igw" {
  vpc_id = aws_vpc.kkp_vpc.id

  tags = {
    Name = "kkp-igw"
  }
}

resource "aws_route_table" "kkp_route_table" {
  vpc_id = aws_vpc.kkp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kkp_igw.id
  }

  tags = {
    Name = "kkp-route-table"
  }
}

resource "aws_route_table_association" "kkp_association" {
  count          = 2
  subnet_id      = aws_subnet.kkp_subnet[count.index].id
  route_table_id = aws_route_table.kkp_route_table.id
}

resource "aws_security_group" "kkp_cluster_sg" {
  vpc_id = aws_vpc.kkp_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kkp-cluster-sg"
  }
}

resource "aws_security_group" "kkp_node_sg" {
  vpc_id = aws_vpc.kkp_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kkp-node-sg"
  }
}

resource "aws_eks_cluster" "kkp" {
  name     = "kkp-cluster"
  role_arn = aws_iam_role.kkp_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.kkp_subnet[*].id
    security_group_ids = [aws_security_group.kkp_cluster_sg.id]
  }
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Get latest EBS CSI addon version
data "aws_eks_addon_version" "ebs" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.kkp.version
  most_recent        = true
}

# Create IAM role for EBS CSI driver addon
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
}

# Attach policy to EBS CSI driver role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_eks_node_group" "kkp" {
  cluster_name    = aws_eks_cluster.kkp.name
  node_group_name = "kkp-node-group"
  node_role_arn   = aws_iam_role.kkp_node_group_role.arn
  subnet_ids      = aws_subnet.kkp_subnet[*].id
  version         = aws_eks_cluster.kkp.version

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"]

  dynamic "remote_access" {
    for_each = var.ssh_key_name != "" ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.kkp_node_sg.id]
    }
  }

  tags = {
    Name = "kkp-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.kkp_node_group_role_policy,
    aws_iam_role_policy_attachment.kkp_node_group_cni_policy,
    aws_iam_role_policy_attachment.kkp_node_group_registry_policy,
  ]
}
resource "aws_iam_role" "kkp_cluster_role" {
  name = "kkp-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kkp_cluster_role_policy" {
  role       = aws_iam_role.kkp_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "kkp_node_group_role" {
  name = "kkp-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
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
