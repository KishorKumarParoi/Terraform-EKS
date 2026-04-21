# EKS Terraform Configuration Guide

## Overview

This directory contains production-ready Terraform code for deploying an AWS EKS (Elastic Kubernetes Service) cluster with complete networking, security, and addon configurations.

## Prerequisites

### Required Tools
- **Terraform**: >= 1.0 ([Install](https://www.terraform.io/downloads))
- **AWS CLI**: >= 2.0 ([Install](https://aws.amazon.com/cli/))
- **kubectl**: >= 1.24 ([Install](https://kubernetes.io/docs/tasks/tools/))
- **aws-iam-authenticator**: For EKS authentication

### AWS Requirements
- Valid AWS credentials configured
- Appropriate IAM permissions for EKS, VPC, IAM, KMS, CloudWatch
- VPC quota available in target region

### Verify Prerequisites

```bash
terraform --version
aws --version
kubectl version --client
aws sts get-caller-identity
```

## File Structure

```
Terraform/
├── main.tf              # Main EKS cluster, VPC, and security configuration
├── addons.tf            # EKS addons (EBS CSI, VPC CNI, CoreDNS, kube-proxy)
├── variable.tf          # Input variable definitions
├── output.tf            # Output value definitions
├── locals.tf            # Local values and computed values
├── versions.tf          # Terraform version and provider requirements
├── terraform.tfvars.example  # Example variable values
└── .gitignore          # Git ignore rules
```

## Configuration Details

### Main Components

#### 1. **VPC & Networking** (main.tf)
- Custom VPC with configurable CIDR block
- Multiple public subnets across availability zones
- Internet Gateway for external connectivity
- Route tables and associations
- Security groups for cluster and worker nodes

#### 2. **EKS Cluster** (main.tf)
- Production-ready EKS cluster
- KMS encryption for etcd secrets
- Private and public endpoint access control
- CloudWatch logging for cluster activities
- OIDC provider for IRSA (IAM Roles for Service Accounts)

#### 3. **Worker Nodes** (main.tf)
- Managed node groups with configurable scaling
- IMDSv2 enforcement (security best practice)
- Support for node taints and labels (blue-green deployment)
- Optional SSH access with security group restrictions

#### 4. **EKS Addons** (addons.tf)
- **EBS CSI Driver**: For persistent volumes
- **VPC CNI**: Networking for pods
- **CoreDNS**: DNS service
- **kube-proxy**: Network proxy

#### 5. **Security & IAM**
- IAM roles for cluster and worker nodes
- IRSA for pod-level IAM authentication
- KMS encryption for EBS volumes
- Security groups with minimal required permissions

#### 6. **Observability**
- CloudWatch log groups for cluster logs
- Auto Scaling group tags for cluster autoscaler
- Configured addon versions for compatibility

## Getting Started

### Step 1: Clone and Navigate

```bash
cd Terraform/
```

### Step 2: Create Variables File

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform working directory
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Step 4: Review and Plan

```bash
# Generate and review the execution plan
terraform plan -out=tfplan

# Optional: Save to file for review
terraform show tfplan
```

### Step 5: Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly (will prompt for approval)
terraform apply

# Note: Cluster creation takes 10-15 minutes
```

### Step 6: Configure kubectl

```bash
# Extract from outputs or run manually
aws eks update-kubeconfig --region us-east-1 --name kkp-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

## Variable Configuration

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region for resources |
| `cluster_name` | `kkp-cluster` | Name of EKS cluster |
| `kubernetes_version` | `1.29` | Kubernetes version |
| `vpc_cidr_block` | `10.0.0.0/16` | VPC CIDR block |
| `node_group_min_size` | `2` | Minimum worker nodes |
| `node_group_max_size` | `5` | Maximum worker nodes |
| `node_instance_types` | `["t3.medium"]` | Instance types for nodes |

### Creating Custom Values File

```bash
cat > terraform.tfvars << EOF
aws_region = "us-east-1"
cluster_name = "my-cluster"
kubernetes_version = "1.29"
vpc_cidr_block = "10.0.0.0/16"

node_group_min_size = 2
node_group_max_size = 5
node_group_desired_size = 2

node_instance_types = ["t3.medium"]
node_disk_size = 50

ssh_key_name = "my-key-pair"
enable_ssh_access = true

common_tags = {
  Terraform   = "true"
  Environment = "production"
  Project     = "MyProject"
  ManagedBy   = "Terraform"
}
EOF
```

## Scaling Configuration

### Auto Scaling

The cluster is configured with auto-scaling support:

```bash
# The cluster autoscaler can automatically scale nodes based on pod requirements
# Auto Scaling Group tags are configured automatically
```

### Manual Scaling

```bash
# Change desired_size in terraform.tfvars
node_group_desired_size = 3

# Apply changes
terraform apply
```

## Blue-Green Deployment

To support blue-green deployments, configure node taints:

```hcl
node_group_taints = [
  {
    key    = "deployment"
    value  = "blue"
    effect = "NoSchedule"
  }
]
```

Pods must have matching tolerations:

```yaml
tolerations:
- key: deployment
  operator: Equal
  value: blue
  effect: NoSchedule
```

## Security Best Practices

✅ **Implemented**:
- KMS encryption for etcd secrets
- Security groups with minimal required permissions
- IMDSv2 enforcement on worker nodes
- IRSA for pod-level IAM authentication
- Network policies support (via security groups)
- SSH access disabled by default
- CloudWatch logging enabled

**Recommendations**:
- Enable VPC Flow Logs
- Use private subnets for worker nodes
- Implement Network Policies
- Enable Pod Security Policies
- Regular backup of etcd
- RBAC configuration
- Audit logging

## Monitoring and Logging

### CloudWatch Logs

```bash
# View cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/"

# Tail logs
aws logs tail "/aws/eks/kkp-cluster/cluster" --follow
```

### Addon Status

```bash
# Check addon status
aws eks describe-addon \
  --cluster-name kkp-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 \
  --query 'addon.status'
```

## Troubleshooting

### Common Issues

**Issue**: Terraform state lock
```bash
# Remove lock (use with caution!)
rm -rf .terraform/.terraform.lock.hcl
```

**Issue**: Provider cache errors
```bash
# Remove and reinitialize
rm -rf .terraform/
terraform init
```

**Issue**: Addon creation fails
```bash
# Check addon prerequisites
aws eks describe-addon-versions \
  --addon-name aws-ebs-csi-driver \
  --kubernetes-version 1.29
```

**Issue**: Node group scaling fails
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name kkp-cluster \
  --nodegroup-name kkp-cluster-node-group

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?Tags[?Key=='eks:nodegroup-name']]"
```

### Debug Commands

```bash
# Validate Terraform configuration
terraform validate

# Check Terraform plan
terraform plan

# Show Terraform state
terraform show

# List resources
terraform state list

# Inspect resource details
terraform state show 'aws_eks_cluster.kkp'
```

## Destroying Resources

**WARNING**: This will delete the EKS cluster and all dependent resources!

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Or destroy specific resource
terraform destroy -target aws_eks_cluster.kkp
```

## Outputs

After successful deployment, useful information is displayed:

```bash
# Retrieve specific output
terraform output cluster_endpoint

# Get kubectl configuration command
terraform output configure_kubectl

# Get all outputs
terraform output
```

## Upgrading Kubernetes Version

```bash
# Update kubernetes_version in terraform.tfvars
kubernetes_version = "1.30"

# Plan changes
terraform plan

# Apply changes (cluster upgrade takes time)
terraform apply
```

## Updating Addons

```bash
# Update addon versions in terraform.tfvars
vpc_cni_version = "v1.16.0-eksbuild.1"
coredns_version = "v1.11.0-eksbuild.1"

# Apply changes
terraform apply
```

## Remote State Management (Production)

For production, use remote state:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Cost Optimization

- **Use spot instances**: Reduce `node_instance_types` to include spot
- **Right-size instances**: Choose appropriate instance types
- **Implement taints**: Prevent unnecessary pod scheduling
- **Use auto-scaling**: Reduce idle node capacity
- **Cleanup unused resources**: Regularly review and remove

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Support

For issues or questions:
1. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
2. Review AWS CloudFormation events
3. Check EKS cluster status in AWS Console
4. Consult AWS Support

## License

MIT License - See [LICENSE](../LICENSE) file for details
