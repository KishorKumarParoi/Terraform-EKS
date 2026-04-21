# Terraform EKS Infrastructure

Production-ready Terraform configuration for deploying a complete AWS EKS (Elastic Kubernetes Service) cluster with all necessary networking, security, and addon components.

## 🎯 Features

✅ **Complete EKS Setup**
- Managed EKS cluster with latest Kubernetes
- Auto-managed node groups
- Support for multiple availability zones
- KMS encryption for etcd secrets

✅ **Networking**
- Custom VPC with configurable CIDR blocks
- Public subnets across multiple AZs
- Internet Gateway for external access
- Route tables and security groups
- Network policies support

✅ **Security**
- IAM roles with least privilege
- IRSA (IAM Roles for Service Accounts)
- KMS key encryption for volumes
- IMDSv2 enforcement
- Security group restrictions
- Optional SSH access control

✅ **Addons & Integrations**
- EBS CSI Driver (persistent volumes)
- VPC CNI (pod networking)
- CoreDNS (DNS resolution)
- kube-proxy (network proxy)

✅ **Observability**
- CloudWatch logging
- Auto Scaling group tags
- Structured output values
- Addon version management

✅ **Production Ready**
- Blue-green deployment support
- Taints and labels configuration
- Auto-scaling ready
- High availability setup
- Comprehensive documentation

✅ **Cost Optimization** 💰
- Spot instance support (60-70% EC2 savings)
- Smaller instance type options (50% savings)
- Minimal logging configuration (reduce CloudWatch costs)
- Environment-specific configurations (dev, staging, prod)
- Cost analysis and optimization guides included

## 💰 Cost Estimates

| Configuration | Monthly Cost | Use Case |
|--------------|-------------|----------|
| **Dev (Cost-Optimized)** | ~$40-50 | Development & Testing |
| **Staging (Balanced)** | ~$80-100 | Staging & Pre-production |
| **Production (Reliable)** | ~$150-180 | Production workloads |
| **Current Setup** | ~$185 | Base configuration (2 t3.medium + 2 ELB) |

**Potential Savings:** 35-75% with cost optimization enabled! See [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md) for details.

## 📋 Prerequisites

### Required
- Terraform >= 1.0
- AWS CLI >= 2.0
- kubectl >= 1.24
- AWS Account with appropriate IAM permissions

### Verification
```bash
terraform --version
aws --version
kubectl version --client
aws sts get-caller-identity
```

## 🚀 Quick Start

### 1. Initialize
```bash
cd Terraform/
terraform init
terraform validate
```

### 2. Configure
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Plan
```bash
terraform plan -out=tfplan
terraform show tfplan
```

### 4. Deploy
```bash
terraform apply tfplan
# Takes approximately 10-15 minutes

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name kkp-cluster
kubectl cluster-info
```

### Using Make
```bash
# Check prerequisites
make check

# Run all setup steps
make all

# Or individual steps
make init
make validate
make plan
make apply

# View outputs
make output

# Check cluster status
make status
make nodes
```

## 📁 File Structure

| File | Purpose |
|------|---------|
| `main.tf` | VPC, EKS cluster, node group, and security |
| `addons.tf` | EKS addons (EBS CSI, VPC CNI, CoreDNS, kube-proxy) |
| `variable.tf` | Input variables with validation |
| `output.tf` | Output values for cluster info |
| `locals.tf` | Computed local values |
| `versions.tf` | Terraform version and providers |
| `terraform.tfvars.example` | Example variable values |
| `TERRAFORM_GUIDE.md` | Comprehensive usage guide |
| `Makefile` | Convenient command shortcuts |
| `.gitignore` | Git ignore rules |

## 🔧 Configuration

### Key Variables

```hcl
# AWS Region
aws_region = "us-east-1"

# Cluster Configuration
cluster_name       = "kkp-cluster"
kubernetes_version = "1.29"

# VPC Configuration
vpc_cidr_block = "10.0.0.0/16"
subnet_count   = 2

# Node Group
node_group_min_size     = 2
node_group_max_size     = 5
node_group_desired_size = 2
node_instance_types     = ["t3.medium"]

# Security
enable_ssh_access = false
```

See `terraform.tfvars.example` and `TERRAFORM_GUIDE.md` for all options.

## 📊 Architecture

```
AWS EKS Cluster (kkp-cluster)
├── Control Plane
│   ├── API Server (KMS encrypted)
│   ├── etcd (KMS encrypted)
│   └── CloudWatch Logs
├── VPC (10.0.0.0/16)
│   ├── Subnet 1 (10.0.0.0/24) - us-east-1a
│   ├── Subnet 2 (10.0.1.0/24) - us-east-1b
│   ├── Internet Gateway
│   └── Route Tables
├── Node Group (Managed)
│   ├── Min: 2 nodes
│   ├── Max: 5 nodes
│   └── Instance Type: t3.medium
├── Addons
│   ├── EBS CSI Driver
│   ├── VPC CNI
│   ├── CoreDNS
│   └── kube-proxy
└── Security
    ├── KMS Keys
    ├── IAM Roles
    ├── Security Groups
    └── OIDC Provider (IRSA)
```

## 🔐 Security Features

- **Encryption**: KMS encryption for etcd secrets
- **Network**: Security groups with minimal required access
- **IAM**: Least privilege roles and policies
- **IRSA**: Pod-level IAM authentication
- **Access**: IMDSv2 enforcement
- **Logging**: CloudWatch audit logging

## 📈 Scaling & Performance

- **Auto Scaling**: Configured for Cluster Autoscaler
- **Node Groups**: Configurable min/max/desired size
- **Blue-Green**: Taints and labels for deployments
- **Cost**: Choose appropriate instance types
- **Multi-AZ**: High availability setup

## 🔄 Common Operations

### Update Kubernetes Version
```bash
# In terraform.tfvars
kubernetes_version = "1.30"

terraform plan
terraform apply
```

### Scale Cluster
```bash
# In terraform.tfvars
node_group_desired_size = 5

terraform apply
```

### Destroy Cluster
```bash
terraform destroy
# WARNING: This deletes all infrastructure!
```

### View Outputs
```bash
terraform output
terraform output cluster_endpoint
terraform output configure_kubectl
```

## 📖 Documentation

- **[TERRAFORM_GUIDE.md](TERRAFORM_GUIDE.md)** - Comprehensive guide with examples
- **[AWS EKS Docs](https://docs.aws.amazon.com/eks/)** - Official AWS documentation
- **[Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)** - Provider documentation

## 🛠 Useful Commands

```bash
# Make commands
make check              # Verify prerequisites
make init              # Initialize Terraform
make validate          # Validate configuration
make plan              # Show execution plan
make apply             # Deploy infrastructure
make destroy           # Destroy infrastructure
make output            # Show outputs
make status            # Show cluster status
make nodes             # List cluster nodes
make pods              # List all pods
make logs              # Tail cluster logs

# Direct Terraform commands
terraform init         # Initialize
terraform validate     # Validate
terraform plan         # Plan changes
terraform apply        # Apply changes
terraform destroy      # Destroy
terraform show         # Show state
terraform output       # Show outputs
terraform fmt -recursive  # Format code
```

## 🐛 Troubleshooting

### Prerequisites not met
```bash
make check  # Verify all requirements
```

### Terraform state issues
```bash
terraform validate
terraform refresh
rm -rf .terraform/
terraform init
```

### Node group scaling fails
```bash
aws eks describe-nodegroup \
  --cluster-name kkp-cluster \
  --nodegroup-name kkp-cluster-node-group
```

### Addon creation fails
```bash
aws eks describe-addon-versions \
  --addon-name aws-ebs-csi-driver \
  --kubernetes-version 1.29
```

See [TERRAFORM_GUIDE.md](TERRAFORM_GUIDE.md#troubleshooting) for more troubleshooting steps.

## 📊 Outputs

After deployment, outputs provide:
- Cluster endpoint and CA certificate
- Node group information
- VPC and subnet IDs
- IAM role ARNs
- Security group IDs
- KMS key information
- kubectl configuration command

```bash
terraform output              # All outputs
terraform output cluster_name # Specific output
terraform output -json        # JSON format
```

## 🔄 State Management

### Local State (Default)
```bash
# State stored in terraform.tfstate
# For development/testing only
```

### Remote State (Production)
Uncomment backend in `versions.tf`:
```hcl
backend "s3" {
  bucket         = "my-terraform-state"
  key            = "eks/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

## 💰 Cost Optimization

- Use `t3.medium` for small workloads
- Enable auto-scaling for right-sizing
- Use spot instances for non-critical workloads
- Regularly review and delete unused resources
- Monitor CloudWatch metrics

## 🚀 Next Steps

1. **Deploy Applications**: Use kubectl to deploy your apps
2. **Setup Ingress**: Configure AWS Load Balancer Controller
3. **Monitoring**: Setup Prometheus and Grafana
4. **Logging**: Configure CloudWatch/ELK integration
5. **CI/CD**: Integrate with Jenkins or GitHub Actions
6. **Backup**: Setup etcd backup and disaster recovery

## 📞 Support

For issues:
1. Check [TERRAFORM_GUIDE.md](TERRAFORM_GUIDE.md)
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check AWS CloudFormation events in console
4. Review security groups and IAM permissions
5. Consult AWS Support

## 📄 License

MIT License - See [LICENSE](../LICENSE)

## 📝 Version History

- **v1.0** - Initial production-ready configuration
  - EKS cluster with managed node groups
  - All required addons pre-configured
  - Security best practices implemented
  - Comprehensive documentation

---

**Last Updated**: April 2026
**Terraform Version**: >= 1.0
**AWS Provider**: ~> 5.0
**Kubernetes**: 1.29+
