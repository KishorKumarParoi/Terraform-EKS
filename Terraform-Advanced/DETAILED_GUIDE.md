# Terraform-Advanced Folder - Detailed Working Guide

This comprehensive guide explains how the Terraform-Advanced EKS cluster configuration works, architectural components, and advanced patterns used.

---

## 📚 **Table of Contents**

1. [Folder Structure](#folder-structure)
2. [Architecture Overview](#architecture-overview)
3. [Core Components](#core-components)
4. [File-by-File Breakdown](#file-by-file-breakdown)
5. [How Everything Works Together](#how-everything-works-together)
6. [Advanced Patterns & Best Practices](#advanced-patterns--best-practices)
7. [Cost Optimization](#cost-optimization)

---

## 📁 **Folder Structure**

```
Terraform-Advanced/
├── main.tf                    # Core infrastructure (VPC, EKS, Security, IAM)
├── addons.tf                  # EKS addons and IRSA roles
├── variable.tf                # Input variables with validation
├── output.tf                  # Output values for cluster info
├── locals.tf                  # Computed local values
├── versions.tf                # Terraform & provider versions
├── terraform.tfvars.dev       # Dev environment (cost-optimized)
├── terraform.tfvars.staging   # Staging environment (balanced)
├── terraform.tfvars.prod      # Production environment (reliable)
├── terraform.tfvars.example   # Template for custom configs
├── Makefile                   # Convenience commands
├── README.md                  # Quick start
├── TERRAFORM_GUIDE.md         # Usage guide
├── COST_OPTIMIZATION.md       # Cost saving strategies
├── UPGRADE_SUMMARY.md         # What's new
└── .gitignore                 # Git exclusions
```

---

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS ACCOUNT                            │
│  (us-east-1 Region)                                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │             VPC (10.0.0.0/16)                        │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │         Internet Gateway                       │ │  │
│  │  │     (Route to 0.0.0.0/0)                       │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                       ↓                               │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │     Route Table (Public Routes)                │ │  │
│  │  │  0.0.0.0/0 → Internet Gateway                  │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │         ↙         ↓         ↘                        │  │
│  │                                                       │  │
│  │  AZ-1 (us-east-1a)  AZ-2 (us-east-1b)              │  │
│  │  ┌───────────────┐   ┌───────────────┐             │  │
│  │  │ Subnet-1      │   │ Subnet-2      │             │  │
│  │  │ 10.0.0.0/24   │   │ 10.0.1.0/24   │             │  │
│  │  │               │   │               │             │  │
│  │  │ ┌───────────┐ │   │ ┌───────────┐ │             │  │
│  │  │ │  Node 1   │ │   │ │  Node 2   │ │             │  │
│  │  │ │(t3.medium)│ │   │ │(t3.medium)│ │             │  │
│  │  │ └───────────┘ │   │ └───────────┘ │             │  │
│  │  │               │   │               │             │  │
│  │  │ ┌────────────────────────────────┐             │  │
│  │  │ │    EKS Control Plane           │             │  │
│  │  │ │ (Managed by AWS)               │             │  │
│  │  │ │ - API Server                   │             │  │
│  │  │ │ - etcd (KMS encrypted)         │             │  │
│  │  │ │ - Scheduler, Controller Mgr    │             │  │
│  │  │ └────────────────────────────────┘             │  │
│  │  │               │   │               │             │  │
│  │  └───────────────┘   └───────────────┘             │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  Security Groups                               │ │  │
│  │  │  - Cluster SG: Port 443 ← Node SG              │ │  │
│  │  │  - Node SG: All traffic from Cluster + VPC     │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  EKS Addons (Deployed as DaemonSets)           │ │  │
│  │  │  - EBS CSI Driver (Persistent Volumes)         │ │  │
│  │  │  - VPC CNI (Pod Networking)                    │ │  │
│  │  │  - CoreDNS (DNS Resolution)                    │ │  │
│  │  │  - kube-proxy (Network Proxy)                  │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  External Services                                   │  │
│  │  - CloudWatch Logs (Control Plane logs)             │  │
│  │  - KMS Keys (etcd & EBS encryption)                 │  │
│  │  - IAM Roles & IRSA                                 │  │
│  │  - OIDC Provider                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 **Core Components**

### **1. VPC (Virtual Private Cloud)**
**What it is:** Isolated network environment for your EKS cluster

**Configuration in main.tf:**
```hcl
resource "aws_vpc" "kkp_vpc" {
  cidr_block           = var.vpc_cidr_block        # 10.0.0.0/16
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

**Key Features:**
- CIDR block: `10.0.0.0/16` (65,536 IP addresses)
- DNS enabled for hostname resolution
- Private IP addressing

**Why:** Provides network isolation and security for your cluster

---

### **2. Subnets (Multiple Availability Zones)**
**What they are:** Smaller network ranges in different AZs for high availability

**Configuration:**
```hcl
resource "aws_subnet" "kkp_subnet" {
  count = var.subnet_count                    # Default: 2 subnets
  
  vpc_id                  = aws_vpc.kkp_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kkp_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}
```

**How CIDR subnetting works:**
```
VPC CIDR:           10.0.0.0/16 (256 subnets possible)
Subnet 1:           10.0.0.0/24 (us-east-1a)
Subnet 2:           10.0.1.0/24 (us-east-1b)
Subnet 3:           10.0.2.0/24 (us-east-1c) [if enabled]
```

**Why Multiple AZs:** Node failure in one AZ won't take down entire cluster

---

### **3. Internet Gateway & Route Tables**
**What they are:** Gateway to the internet and routing rules

**Configuration:**
```hcl
resource "aws_internet_gateway" "kkp_igw" {
  vpc_id = aws_vpc.kkp_vpc.id
}

resource "aws_route_table" "kkp_route_table" {
  vpc_id = aws_vpc.kkp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kkp_igw.id
  }
}
```

**How it works:**
```
Packet destination 1.1.1.1 (external)
           ↓
Does it match 10.0.0.0/16? NO
           ↓
Match 0.0.0.0/0? YES
           ↓
Forward to Internet Gateway
           ↓
Out to the internet!
```

---

### **4. Security Groups (Firewalls)**
**What they are:** Virtual firewalls controlling traffic flow

**Two Security Groups:**

**a) Cluster Security Group:**
```hcl
resource "aws_security_group" "kkp_cluster_sg" {
  # INGRESS: Port 443 from Node SG (API Server)
  # EGRESS: All traffic allowed (0.0.0.0/0)
}
```

**Why:** Protects EKS control plane; only allows nodes to communicate

**b) Node Security Group:**
```hcl
resource "aws_security_group" "kkp_node_sg" {
  # INGRESS:
  # - All traffic from VPC (10.0.0.0/16)
  # - All traffic from Cluster SG
  # - SSH (22) if enabled
  
  # EGRESS: All traffic allowed
}
```

**Why:** Worker nodes need to communicate with each other and control plane

---

### **5. EKS Cluster (Kubernetes Control Plane)**
**What it is:** AWS-managed Kubernetes control plane

**Configuration:**
```hcl
resource "aws_eks_cluster" "kkp" {
  name     = var.cluster_name              # "kkp-cluster"
  role_arn = aws_iam_role.kkp_cluster_role.arn
  version  = var.kubernetes_version        # "1.35"

  vpc_config {
    subnet_ids              = aws_subnet.kkp_subnet[*].id
    security_group_ids      = [aws_security_group.kkp_cluster_sg.id]
    endpoint_private_access = var.cluster_endpoint_private_access  # true
    endpoint_public_access  = var.cluster_endpoint_public_access   # true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.cluster_log_types  # ["api"]
}
```

**What Happens:**
1. AWS launches 3 master nodes (hidden from you) in AWS-managed subnets
2. They run etcd (database), API server, scheduler, controller manager
3. They're replicated across 3 AZs automatically
4. You pay $0.10/hour for this managed service

**Encryption:**
- etcd is encrypted with KMS key
- Secrets at rest are encrypted
- You control the KMS key

---

### **6. Node Group (Worker Nodes)**
**What they are:** EC2 instances where your pods run

**Configuration:**
```hcl
resource "aws_eks_node_group" "kkp" {
  cluster_name    = aws_eks_cluster.kkp.name
  node_role_arn   = aws_iam_role.kkp_node_group_role.arn
  subnet_ids      = aws_subnet.kkp_subnet[*].id
  version         = var.kubernetes_version

  scaling_config {
    min_size     = var.node_group_min_size        # 2
    max_size     = var.node_group_max_size        # 5
    desired_size = var.node_group_desired_size    # 2
  }

  instance_types = var.node_instance_types       # ["t3.medium"]
  disk_size      = var.node_disk_size            # 50 GB

  # Cost optimization: Use Spot instances
  capacity_type = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"
}
```

**How Auto Scaling Works:**
```
Current pods requesting 2 CPU  →  Current nodes can handle (2x t3.medium = 4 CPU)
                                  ↓ Still has capacity

New deployment requesting 3 CPU  →  Not enough space!
                                    ↓
                        Cluster Autoscaler detects
                                    ↓
                    Launches new node (3rd node)
                                    ↓
                    Pod gets scheduled on new node
```

---

### **7. EKS Addons (Essential Components)**
**What they are:** AWS-managed Kubernetes add-on deployments

#### **a) EBS CSI Driver**
```hcl
resource "aws_eks_addon" "ebs_csi" {
  addon_name            = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
}
```

**What it does:**
```
Your Pod → Requests PVC (Persistent Volume Claim)
         → EBS CSI Driver detects request
         → Creates EBS volume in AWS
         → Attaches to your node
         → Mounts into your pod
         → Pod can read/write data
```

**Example:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    storage: 10Gi
```

#### **b) VPC CNI (Pod Networking)**
```hcl
resource "aws_eks_addon" "vpc_cni" {
  addon_name = "vpc-cni"
}
```

**What it does:**
```
When pod is created:
  1. CNI plugin assigns pod an IP from VPC CIDR (10.0.0.0/16)
  2. Pod gets real VPC IP (not overlay network IP)
  3. Pod can communicate directly with EC2 instances
  4. Better performance than overlay networks
  
Example:
  Pod IP: 10.0.0.50
  Node IP: 10.0.0.10
  Both in same VPC, can reach directly
```

**Why this matters:**
- Better latency
- Works with AWS network policies
- Direct VPC networking

#### **c) CoreDNS**
```hcl
resource "aws_eks_addon" "coredns" {
  addon_name = "coredns"
}
```

**What it does:**
```
Pod: curl http://nginx-service.default.svc.cluster.local
       ↓
CoreDNS: Resolves to ClusterIP 172.20.0.100
       ↓
Pod gets response from nginx pods
```

#### **d) kube-proxy**
```hcl
resource "aws_eks_addon" "kube_proxy" {
  addon_name = "kube-proxy"
}
```

**What it does:**
```
Pod requests Service:
  service-name:8080
       ↓
kube-proxy adds iptables rules
       ↓
Traffic forwarded to one of the backend pods
       ↓
Load balanced across pod replicas
```

---

### **8. IAM Roles & IRSA (Pod-Level IAM)**
**What they are:** AWS identity and access management

#### **a) Cluster IAM Role**
```hcl
resource "aws_iam_role" "kkp_cluster_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

**What it allows:** EKS service to manage networking, security groups, etc.

#### **b) Node IAM Role**
```hcl
resource "aws_iam_role" "kkp_node_group_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

**What it allows:**
- Pull ECR images
- Write CloudWatch logs
- Get Secrets from Secrets Manager
- Upload metrics

#### **c) IRSA (IAM Roles for Service Accounts)**
```hcl
resource "aws_iam_role" "ebs_csi_driver" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::ACCOUNT:oidc-provider/OIDC_PROVIDER"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "OIDC_PROVIDER:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}
```

**How IRSA Works:**
```
EBS CSI Pod                 AWS API
     ↓                        ↑
Step 1: Pod gets JWT token from Kubernetes API
     ↓
Step 2: Pod presents JWT to AWS STS
     ↓
Step 3: AWS checks OIDC provider (trusts Kubernetes)
     ↓
Step 4: STS issues temporary credentials
     ↓
Step 5: Pod uses credentials to create EBS volumes
     ↓
Step 6: EBS volume attached to node and pod
```

**Why this is better than Node IAM:**
- Each pod only gets permissions it needs
- No shared credentials
- Fine-grained access control

---

### **9. KMS Encryption**
**What it is:** Key management for encrypting sensitive data

**Two KMS Keys:**

#### **a) EKS etcd Key**
```hcl
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
```

**What it encrypts:**
- etcd database (Kubernetes API database)
- All secrets stored in etcd
- ConfigMaps marked for encryption

**Why:**
```
Without encryption:
  Secret stored in etcd: password=supersecret
  Attacker gains disk access: Can read password

With KMS encryption:
  Secret encrypted: <encrypted blob>
  Attacker gains disk access: Can't read without KMS key
  KMS key stored separately: Safe!
```

#### **b) EBS Volume Key**
```hcl
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS encryption"
  enable_key_rotation     = true
}
```

**What it encrypts:**
- EC2 root volumes (node disks)
- Persistent volumes (PVC data)

---

### **10. CloudWatch Logging**
**What it captures:**
```hcl
enabled_cluster_log_types = ["api"]  # Cost-optimized
# OR
enabled_cluster_log_types = [
  "api",
  "audit", 
  "authenticator",
  "controllerManager",
  "scheduler"
]  # Full logging
```

**Log Types:**
- **api**: API server requests (HTTP 200, 400, etc.)
- **audit**: Who accessed what (security)
- **authenticator**: Token validation
- **controllerManager**: Deployment controller logs
- **scheduler**: Pod scheduling decisions

**Example log:**
```json
{
  "level": "INFO",
  "timestamp": "2026-04-21T10:30:45.123Z",
  "message": "API request processed",
  "user": "system:serviceaccount:kube-system:aws-node",
  "verb": "list",
  "objectRef": {
    "resource": "pods",
    "namespace": "default"
  }
}
```

---

### **11. OIDC Provider (Trust for IRSA)**
**What it is:** OpenID Connect provider that Kubernetes acts as

**Configuration:**
```hcl
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.kkp.identity[0].oidc[0].issuer
}
```

**How it works:**
```
AWS:  "I trust Kubernetes at https://oidc.eks.us-east-1.amazonaws.com/id/ABC123"
      (I verified the certificate with thumbprint)

Kubernetes: "I sign tokens for my service accounts"

Pod with JWT:
  "I am system:serviceaccount:kube-system:ebs-csi-driver"
  (Signed by Kubernetes)
       ↓
AWS: "Kubernetes signed this. I trust Kubernetes. User is ebs-csi-driver."
       ↓
AWS: "ebs-csi-driver role can create EBS volumes. Allowed!"
```

---

## 📄 **File-by-File Breakdown**

### **main.tf (Core Infrastructure)**

**Sections:**
1. **Provider Configuration** - AWS & TLS providers
2. **Data Sources** - Query AWS for current info
3. **VPC & Networking** - VPC, Subnets, IGW, Route Tables
4. **Security Groups** - Cluster & Node firewalls
5. **EKS Cluster** - The control plane
6. **Node Group** - Worker nodes with auto-scaling
7. **IAM Roles** - Permissions for cluster and nodes
8. **CloudWatch Logs** - Control plane logging
9. **OIDC Provider** - Trust for IRSA

**Dependencies:**
```
VPC
  ↓
Subnets + Internet Gateway
  ↓
Route Table + Associations
  ↓
Security Groups
  ↓
IAM Roles
  ↓
EKS Cluster
  ↓
Node Group
  ↓
OIDC Provider (uses cluster info)
```

---

### **addons.tf (EKS Add-ons)**

**Sections:**
1. **EKS Addons** - 4 managed addons
2. **IRSA Roles** - Pod-level IAM
3. **Auto Scaling Tags** - Cluster autoscaler discovery
4. **KMS Keys** - Encryption

**Key Pattern - IRSA Role:**
```hcl
resource "aws_iam_role" "addon_role" {
  assume_role_policy = jsonencode({
    # "AWS STS, if Kubernetes signs the token, trust it"
  })
}

resource "aws_eks_addon" "addon_name" {
  service_account_role_arn = aws_iam_role.addon_role.arn
  # "Use this role when running as this service account"
}
```

---

### **variable.tf (Input Variables)**

**Key Variables:**

```hcl
# AWS
aws_region = "us-east-1"

# Cluster
cluster_name       = "kkp-cluster"
kubernetes_version = "1.35"

# VPC
vpc_cidr_block = "10.0.0.0/16"
subnet_count   = 2  # Number of AZs

# Nodes
node_instance_types    = ["t3.medium"]
node_group_min_size    = 2
node_group_max_size    = 5
node_group_desired_size = 2

# Cost Optimization
enable_spot_instances = false
use_smaller_instance_types = false

# Logging
cluster_log_types = ["api"]
log_retention_days = 7

# SSH
enable_ssh_access = false
```

**Validations:**
```hcl
validation {
  condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
  error_message = "Must be valid AWS region"
}
```

---

### **output.tf (Exported Values)**

**Example Outputs:**
```hcl
output "cluster_endpoint" {
  value       = aws_eks_cluster.kkp.endpoint
  description = "EKS cluster API endpoint"
  # Example: https://ABC123.eks.us-east-1.amazonaws.com
}

output "cluster_oidc_issuer" {
  value = aws_eks_cluster.kkp.identity[0].oidc[0].issuer
  # Example: https://oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.kkp.name}"
  # Easy copy-paste command
}
```

---

### **locals.tf (Computed Values)**

```hcl
locals {
  cluster_id = aws_eks_cluster.kkp.id
  oidc_provider_url = replace(
    aws_eks_cluster.kkp.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
  # Extract domain from full URL
  
  account_id = data.aws_caller_identity.current.account_id
  # Get AWS account ID dynamically
  
  tags = merge(
    var.common_tags,
    {
      "Cluster"   = var.cluster_name
      "CreatedAt" = timestamp()
    }
  )
  # Merge default tags with creation timestamp
}
```

---

### **versions.tf (Terraform Configuration)**

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Why versions matter:**
```
Without pinning:
  terraform init → Latest provider → May have breaking changes

With pinning (~> 5.0):
  terraform init → Latest 5.x version
  Allows bug fixes, prevents major breaking changes
```

---

## 🔄 **How Everything Works Together**

### **Scenario: Deploying an Application**

```
Step 1: You run kubectl create deployment
        ↓
Step 2: Request goes to EKS API Server (control plane)
        ↓
Step 3: API Server validates request with:
        - Authentication (RBAC)
        - Authorization (who can do what)
        ↓
Step 4: API Server creates Deployment object
        (Stored encrypted in etcd with KMS key)
        ↓
Step 5: Deployment Controller notices new deployment
        ↓
Step 6: Controller creates ReplicaSet (to manage pod replicas)
        ↓
Step 7: Scheduler looks at pods needing placement
        ↓
Step 8: Scheduler checks node capacity
        - Node 1: 2 CPU available (has 2x t3.medium = 4 CPU, 2 already used)
        - Node 2: 2 CPU available
        ↓
Step 9: Pod gets scheduled on Node 2
        ↓
Step 10: kubelet on Node 2 receives assignment
        ↓
Step 11: kubelet requests:
        - Image from ECR (using node IAM role)
        - PVC creation (triggers EBS CSI driver)
        ↓
Step 12: EBS CSI driver:
        - Assumes ebs-csi-driver IAM role (via IRSA + OIDC)
        - Calls AWS API to create EBS volume
        - Attaches to node
        - kubelet mounts it
        ↓
Step 13: kubelet creates container
        - Uses VPC CNI to assign pod an IP
        - Pod gets IP from VPC CIDR (10.0.0.50)
        ↓
Step 14: CoreDNS resolves service names
        ↓
Step 15: kube-proxy creates iptables rules for load balancing
        ↓
Step 16: Pod is running and ready to serve traffic!
        ↓
Step 17: CloudWatch receives logs from all components
```

---

## 🎯 **Advanced Patterns & Best Practices**

### **Pattern 1: Dynamic Subnet Creation**

```hcl
# Instead of hardcoding 2 subnets, create N subnets:
resource "aws_subnet" "kkp_subnet" {
  count = var.subnet_count  # 2, 3, or more

  vpc_id            = aws_vpc.kkp_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.kkp_vpc.cidr_block, 8, count.index)
  # Takes VPC CIDR (10.0.0.0/16) and creates:
  # count.index=0 → 10.0.0.0/24
  # count.index=1 → 10.0.1.0/24
  # count.index=2 → 10.0.2.0/24
  
  availability_zone = data.aws_availability_zones.available.names[count.index]
  # Distributes across AZs automatically
}
```

**Why this is better:**
- Parameterized: Change `subnet_count = 3` → 3 AZs deployed
- Automatic CIDR calculation: No manual IP planning
- Scales with AZ availability

---

### **Pattern 2: Separated Security Group Rules**

**Problem (Circular Dependency):**
```hcl
# ❌ This creates a cycle:
resource "aws_security_group" "cluster" {
  # Cluster needs to accept traffic from nodes
  ingress {
    security_groups = [aws_security_group.nodes.id]  # References nodes SG
  }
}

resource "aws_security_group" "nodes" {
  # Nodes need to accept traffic from cluster
  ingress {
    security_groups = [aws_security_group.cluster.id]  # References cluster SG
  }
  # ^^^ Both SGs reference each other = CIRCULAR DEPENDENCY
}
```

**Solution (Separate Rules):**
```hcl
# ✅ Define SGs without mutual references
resource "aws_security_group" "cluster" {
  # Empty, only egress
}

resource "aws_security_group" "nodes" {
  # Empty, only egress
}

# Then define rules separately
resource "aws_security_group_rule" "cluster_ingress" {
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  # No circular dependency!
}
```

---

### **Pattern 3: Dynamic IRSA Configuration**

```hcl
# Instead of hardcoding service account:
resource "aws_iam_role" "addon_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Condition = {
        StringEquals = {
          # Dynamically construct from cluster OIDC issuer
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:NAMESPACE:SA_NAME"
        }
      }
    }]
  })
}
```

---

### **Pattern 4: Count vs For_Each (and why we fixed it)**

**❌ Problem: Using for_each with dynamic values**
```hcl
resource "aws_autoscaling_group_tag" "example" {
  for_each = toset(
    [for asg in data.aws_autoscaling_groups.node_group.names : asg]
  )
  # ^ Cannot use for_each with values from data source!
  # Terraform needs to know all keys during planning phase
  # But ASG names are only known after nodes are created
}
```

**✅ Solution: Use count for dynamic values**
```hcl
resource "aws_autoscaling_group_tag" "example" {
  count = length(data.aws_autoscaling_groups.node_group.names)
  # count can reference dynamic data!
  
  autoscaling_group_name = data.aws_autoscaling_groups.node_group.names[count.index]
}
```

**When to use what:**
- **for_each**: Static keys (known at plan time)
- **count**: Dynamic lengths (only known at apply time)

---

## 💰 **Cost Optimization**

### **Configuration Options:**

**Development (Save 75%):**
```hcl
enable_spot_instances      = true     # -60% EC2
use_smaller_instance_types = true     # -50% EC2  
node_group_min_size        = 1        # Single node
cluster_log_types          = ["api"]  # Minimal logging
# Monthly: $40-50
```

**Staging (Save 50%):**
```hcl
enable_spot_instances = true
node_instance_types   = ["t3.small"]
node_group_min_size   = 2
# Monthly: $80-100
```

**Production (Balanced):**
```hcl
enable_spot_instances = false  # Avoid interruptions
node_instance_types   = ["t3.medium"]
node_group_min_size   = 3      # HA
cluster_log_types     = ["api", "audit"]
# Monthly: $150-180
```

---

## 📊 **Cost Breakdown**

```
DEFAULT CONFIGURATION
├── EKS Cluster:        $73/month
├── EC2 (2x t3.medium): $68/month
├── Load Balancers (2):  $37/month
└── Storage/Logs:        $8/month
    TOTAL: $186/month

OPTIMIZED CONFIGURATION
├── EKS Cluster:        $73/month (same)
├── EC2 (Spot):         $20/month (-65%)
├── Load Balancers (1):  $18/month (-50%)
└── Minimal Logging:     $2/month (-75%)
    TOTAL: $113/month (39% savings!)
```

---

## 🚀 **Deployment Commands**

```bash
# Initialize
cd Terraform-Advanced/
terraform init

# Validate configuration
terraform validate

# Plan for dev environment
make plan-dev

# Apply dev configuration
make apply-dev

# For production
make apply-prod

# View outputs
terraform output

# Destroy (cleanup)
terraform destroy -auto-approve
```

---

## 📚 **Key Concepts Summary**

| Concept | Purpose | AWS Service |
|---------|---------|-------------|
| **VPC** | Network isolation | VPC |
| **Subnets** | Availability zones | Subnets |
| **IGW** | Internet access | Internet Gateway |
| **Route Table** | Network routing | Route Tables |
| **Security Group** | Firewall | Security Groups |
| **EKS Cluster** | Control plane | EKS |
| **Node Group** | Worker nodes | EC2 Auto Scaling |
| **Add-ons** | Essential services | EKS Add-ons |
| **IAM** | Permissions | IAM |
| **IRSA** | Pod-level IAM | IAM + OIDC |
| **KMS** | Encryption | KMS |
| **CloudWatch** | Logging | CloudWatch Logs |

---

## 🎓 **Learning Path**

1. **Day 1:** Understand VPC & Networking concepts
2. **Day 2:** Learn about EKS cluster components
3. **Day 3:** Deep dive into IAM & IRSA
4. **Day 4:** Understand Kubernetes addons
5. **Day 5:** Cost optimization strategies
6. **Day 6:** Deploy and experiment with Terraform
7. **Day 7:** Customize for your use case

---

**Remember:** This configuration is production-ready and follows AWS best practices. Customize variables for your specific needs!
