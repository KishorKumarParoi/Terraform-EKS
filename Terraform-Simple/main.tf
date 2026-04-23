# AWS Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = merge(local.common_tags, var.additional_tags)
  }
}

# VPC Resource
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_config.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.vpc_config.name
  }
}

# Subnets
resource "aws_subnet" "main" {
  count                   = local.subnet_config.count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = element(local.subnet_config.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.subnet_config.name_prefix}-${count.index + 1}"
  }

  depends_on = [aws_vpc.main]
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.igw_config.name
  }

  depends_on = [aws_vpc.main]
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = local.route_table_config.name
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table Associations
resource "aws_route_table_association" "main" {
  count          = local.subnet_config.count
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id

  depends_on = [aws_route_table.main]
}

# Network ACL (Optional - for additional security)
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  # Allow all ingress traffic
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all egress traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.project_prefix}-nacl-${local.environment_suffix}"
  }
}

# Security Group (Optional - for future use)
resource "aws_security_group" "main" {
  name        = "${local.project_prefix}-sg-${local.environment_suffix}"
  description = "Main security group for ${local.project_prefix}"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.vpc_config.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_prefix}-sg-${local.environment_suffix}"
  }

  depends_on = [aws_vpc.main]
}
