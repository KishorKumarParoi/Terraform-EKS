################################################################################
# AWS Provider Variables
################################################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1)"
  }
}

################################################################################
# Common Tags
################################################################################

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "production"
    Project     = "Mega-Project"
    ManagedBy   = "Terraform"
  }
}

################################################################################
# EKS Cluster Configuration
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "kkp-cluster"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.35"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format X.Y (e.g., 1.35)"
  }
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "List of EKS cluster log types to enable. For cost optimization, use [\"api\"] only. Default enables all (higher cost)."
  type        = list(string)
  default     = ["api"]
  # Cost-optimized default. Uncomment below for full logging:
  # default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days (7 = cost optimized)"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch value."
  }
}

variable "enable_detailed_logging" {
  description = "Enable detailed EKS control plane logging (increases CloudWatch costs). Set to false for cost optimization."
  type        = bool
  default     = false
}

################################################################################
# Cost Optimization Variables
################################################################################

variable "enable_spot_instances" {
  description = "Enable Spot instances for node group (saves 60-70% on EC2 costs). Recommended for non-critical workloads."
  type        = bool
  default     = false
}

variable "max_spot_price" {
  description = "Maximum price willing to pay for Spot instances. Leave empty for on-demand price."
  type        = string
  default     = ""
}

variable "use_smaller_instance_types" {
  description = "Use smaller, more cost-effective instance types (t3.small vs t3.medium)"
  type        = bool
  default     = false
}

variable "enable_cost_optimization" {
  description = "Enable all cost optimization features (Spot + smaller instances + minimal logging)"
  type        = bool
  default     = false
}

################################################################################
# VPC Configuration
################################################################################

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR."
  }
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.subnet_count >= 2 && var.subnet_count <= 3
    error_message = "Subnet count must be between 2 and 3."
  }
}

################################################################################
# Node Group Configuration
################################################################################

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2

  validation {
    condition     = var.node_group_min_size >= 1
    error_message = "Minimum node group size must be at least 1."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 5

  validation {
    condition     = var.node_group_max_size >= var.node_group_min_size
    error_message = "Max size must be greater than or equal to min size."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2

  validation {
    condition     = var.node_group_desired_size >= var.node_group_min_size && var.node_group_desired_size <= var.node_group_max_size
    error_message = "Desired size must be between min and max size."
  }
}

variable "node_instance_types" {
  description = "Instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "Root disk size for worker nodes in GiB"
  type        = number
  default     = 50

  validation {
    condition     = var.node_disk_size >= 20
    error_message = "Node disk size must be at least 20 GiB."
  }
}

variable "node_group_labels" {
  description = "Labels to apply to worker nodes"
  type        = map(string)
  default = {
    "node-type" = "general"
  }
}

variable "node_group_taints" {
  description = "Taints to apply to worker nodes (for blue-green deployment, etc.)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

################################################################################
# SSH Access Configuration
################################################################################

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.ssh_key_name == "" || can(regex("^[a-zA-Z0-9_-]+$", var.ssh_key_name))
    error_message = "SSH key name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "enable_ssh_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed to SSH into worker nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

################################################################################
# EKS Addons Configuration
################################################################################

variable "vpc_cni_version" {
  description = "Version of VPC CNI addon"
  type        = string
  default     = "v1.15.0-eksbuild.1"
}

variable "coredns_version" {
  description = "Version of CoreDNS addon"
  type        = string
  default     = "v1.10.1-eksbuild.2"
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy addon"
  type        = string
  default     = "v1.35.0-eksbuild.1"
}
