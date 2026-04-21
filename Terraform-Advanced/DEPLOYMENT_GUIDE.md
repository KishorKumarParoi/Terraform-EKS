# Automated EKS Deployment Guide

## 📋 Overview

The `scripts/Infra-Server/run.sh` script automates the complete deployment of:
- ✅ AWS Infrastructure (VPC, Subnets, Security Groups)
- ✅ EKS Cluster (Kubernetes Control Plane)
- ✅ Node Groups (Worker Nodes)
- ✅ Kubernetes Addons (EBS CSI, VPC CNI, CoreDNS)
- ✅ kubectl & eksctl installation
- ✅ OIDC Provider configuration

**Typical Duration:** 15-20 minutes

---

## 🚀 Quick Start

### Prerequisites
Before running the script, ensure you have:

1. **AWS Credentials Configured**
   ```bash
   # Option A: Interactive configuration
   aws configure
   # Then enter:
   # AWS Access Key ID: [your-key]
   # AWS Secret Access Key: [your-secret]
   # Default region: us-east-1
   # Default output format: json
   
   # Option B: Environment variables
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

2. **Terraform Files Ready**
   ```bash
   ls ~/Desktop/DevOps/Mega-Project-Terraform/Terraform/
   # Should show: main.tf, variable.tf, output.tf, addons.tf, versions.tf, etc.
   ```

3. **Ubuntu/Debian System**
   ```bash
   lsb_release -a
   # Should show Ubuntu or Debian
   ```

### Run the Deployment

```bash
# Option 1: Run directly from scripts directory
cd ~/Desktop/DevOps/Mega-Project-Terraform/scripts/Infra-Server
sudo bash run.sh

# Option 2: Run with output logging
sudo bash run.sh | tee deployment.log

# Option 3: Keep terminal session live with tmux
tmux new-session -s deploy
cd ~/Desktop/DevOps/Mega-Project-Terraform/scripts/Infra-Server
sudo bash run.sh
# Detach: Ctrl+B, D
# Reattach: tmux attach-session -s deploy
```

---

## 📊 What the Script Does (Step by Step)

| Section | Action | Time |
|---------|--------|------|
| 1 | Install/verify AWS CLI | 1-2 min |
| 2 | Navigate to Terraform directory | <1 min |
| 3 | Install Terraform | 1-2 min |
| 4 | **Initialize & Apply Terraform** | **10-15 min** |
| 5 | Configure kubectl | 1 min |
| 6 | Install kubectl | 2-3 min |
| 7 | Install eksctl | 1 min |
| 8 | Configure OIDC Provider | 1 min |
| 9 | Deploy EBS CSI Driver | 3-5 min |
| 10 | Deploy Kubernetes resources | 1 min |
| 11 | Verify installation | 1 min |
| 12 | Install Helm | 2 min |
| 13 | Install Metrics Server | 1 min |

---

## ✅ Verification After Deployment

```bash
# Check nodes are ready
kubectl get nodes
# Expected: 2-5 nodes with STATUS=Ready

# Check cluster info
kubectl cluster-info
# Should show API server endpoint and DNS

# Check EBS CSI Driver
kubectl get pods -n kube-system | grep ebs-csi
# Should show ebs-csi-controller and ebs-csi-node pods

# Check all addons
kubectl get daemonsets -n kube-system
# Should show vpc-node, kube-proxy, and ebs-csi-node

# View cluster details
aws eks describe-cluster --name kkp-cluster --region us-east-1 --output table
```

---

## 🔧 Troubleshooting

### Error: "Terraform directory not found"
```bash
# Verify Terraform files exist
ls ~/Desktop/DevOps/Mega-Project-Terraform/Terraform/*.tf

# If missing, go back and create them using the Terraform configuration
```

### Error: "No cluster found for name: kkp-cluster"
```bash
# Check Terraform apply status
terraform -version
terraform state list  # Should show cluster resource

# If empty, Terraform apply failed - check logs above
# Common causes:
# - AWS credentials not valid
# - AWS quota exceeded (check EC2 limits)
# - Network connectivity issues
```

### Error: "You do not have permission"
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Should show your AWS account ID
# If error, reconfigure credentials:
aws configure
```

### EBS CSI pods stuck in pending
```bash
# Check node resources
kubectl top nodes

# Check pod logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check service account
kubectl describe sa ebs-csi-controller-sa -n kube-system
```

---

## 📝 Environment Variables (Optional)

```bash
# Set these before running the script for faster execution

export AWS_REGION="us-east-1"
export CLUSTER_NAME="kkp-cluster"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Then run:
sudo bash run.sh
```

---

## 🧹 Clean Up (If Needed)

To destroy the infrastructure:

```bash
cd ~/Desktop/DevOps/Mega-Project-Terraform/Terraform

# Review what will be deleted
terraform plan -destroy

# Actually destroy
terraform destroy -auto-approve

# Verify deletion
aws eks list-clusters --region us-east-1
# Should be empty after 2-3 minutes
```

---

## 📚 Next Steps After Successful Deployment

1. **Deploy Your Application**
   ```bash
   kubectl apply -f ~/path/to/your/manifest.yaml
   ```

2. **Configure Persistent Storage**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: ebs
   provisioner: ebs.csi.aws.com
   EOF
   ```

3. **Setup Monitoring**
   ```bash
   # Metrics Server is already installed
   kubectl top nodes
   ```

4. **Install Ingress Controller**
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
   ```

---

## 📞 Support

For issues or questions:

1. Check script logs: `cat deployment.log`
2. Check Terraform state: `terraform state list`
3. Check kubectl: `kubectl get all -A`
4. Check AWS console: https://console.aws.amazon.com/eks

---

## 🔐 Security Notes

- ✅ Use AWS IAM roles in production (not hardcoded credentials)
- ✅ Terraform state is stored locally (move to S3 backend for team use)
- ✅ EKS cluster has CloudWatch logging enabled
- ✅ KMS encryption enabled for etcd secrets
- ✅ IRSA (IAM Roles for Service Accounts) configured for pod-level IAM

---

**Last Updated:** April 21, 2026  
**Script Location:** `/Users/kishorkumarparoi/Desktop/DevOps/Mega-Project-Terraform/scripts/Infra-Server/run.sh`  
**Terraform Location:** `/Users/kishorkumarparoi/Desktop/DevOps/Mega-Project-Terraform/Terraform/`
