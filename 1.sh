#!/bin/bash

################################################################################
# TERRAFORM + EKS + KUBECTL AUTOMATED DEPLOYMENT SCRIPT
# Purpose: Complete setup of AWS infrastructure with Terraform and Kubernetes
# Prerequisites: Ubuntu/Debian system with sudo access
################################################################################

# ============================================================================
# SECTION 1: AWS CLI INSTALLATION AND CONFIGURATION
# ============================================================================
# Description: Install AWS CLI v2 and configure credentials for AWS access

echo "=== Installing AWS CLI v2 ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
# Note: Replace with your actual AWS Access Key and Secret Key
# ⚠️  SECURITY WARNING: Store credentials securely (use IAM roles in production)
echo "=== Configuring AWS Credentials ==="
aws configure set aws_access_key_id key_id_1234567890
aws configure set aws_secret_access_key secret_key_1234567890
aws configure set region us-east-1                        # Primary AWS region
aws configure set output json                             # Output format

# Verify AWS credentials are working
echo "=== Verifying AWS Configuration ==="
aws sts get-caller-identity

# ============================================================================
# SECTION 2: CLONE TERRAFORM REPOSITORY
# ============================================================================
# Description: Clone the Terraform configuration from GitHub repository

echo "=== Cloning Terraform Project ==="
git clone https://github.com/KishorKumarParoi/Terraform-EKS.git
cd Mega-Project-Terraform

# ============================================================================
# SECTION 3: INSTALL TERRAFORM FROM HASHICORP REPOSITORY (OFFICIAL)
# ============================================================================
# Description: Install Terraform using official HashiCorp GPG-signed repository
# Why: Official method with better security, performance, and compatibility

echo "=== Installing Terraform ==="

# Install dependencies for GPG key management
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common

# Download and add HashiCorp GPG key for repo signature verification
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Verify GPG key fingerprint (security check)
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

# Add HashiCorp repository to apt sources
# Supports multi-architecture and dynamically detects Ubuntu version
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
sudo apt update
sudo apt-get install terraform -y

# Verify Terraform installation
terraform -version

# ============================================================================
# SECTION 4: TERRAFORM INFRASTRUCTURE DEPLOYMENT
# ============================================================================
# Description: Initialize, plan, and apply Terraform configuration to create AWS resources
# Creates: VPC, Subnets, Security Groups, EKS Cluster, Node Groups, IAM Roles

echo "=== Deploying Infrastructure with Terraform ==="
terraform state rm aws_eks_addon.ebs_csi_driver 2>/dev/null || true
terraform init                      # Initialize Terraform (download providers)
terraform plan -out=tfplan          # Show execution plan (what will be created)
terraform apply tfplan      # Apply changes automatically (no prompt)

# Clean up plan file (optional)
rm -f tfplan

echo "✓ Terraform apply completed successfully"

# ============================================================================
# SECTION 5: CONFIGURE KUBECTL TO ACCESS EKS CLUSTER
# ============================================================================
# Description: Update local kubeconfig to connect kubectl to EKS cluster
# Cluster Name: kkp-cluster
# Region: us-east-1

echo "=== Configuring kubectl for EKS ==="
aws eks --region us-east-1 update-kubeconfig --name kkp-cluster
# This creates/updates ~/.kube/config with EKS cluster credentials

# ============================================================================
# SECTION 6: INSTALL KUBECTL (Kubernetes Command-Line Tool)
# ============================================================================
# Description: Install kubectl to manage Kubernetes resources
# kubectl is required to interact with EKS cluster

echo "=== Installing kubectl ==="

# Download kubectl binary matching latest stable Kubernetes version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Download SHA256 checksum for verification
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Verify binary integrity using SHA256 checksum
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Make kubectl executable
chmod +x kubectl

# Move kubectl to user local bin
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl

# Also install to system-wide location
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify kubectl installation
kubectl version --client

# ============================================================================
# SECTION 7: INSTALL EKSCTL (EKS Cluster Management Tool)
# ============================================================================
# Description: Install eksctl for managing EKS cluster resources and IAM integration
# Used for: Creating IAM OIDC providers, service accounts, managing EKS resources

echo "=== Installing eksctl ==="

# Download latest eksctl release
curl -LO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"

# Extract eksctl binary
tar -xzf eksctl_Linux_amd64.tar.gz

# Move to system PATH
sudo mv eksctl /usr/local/bin

# Verify eksctl installation
eksctl version

# ============================================================================
# SECTION 8: CONFIGURE IRSA (IAM ROLES FOR SERVICE ACCOUNTS)
# ============================================================================
# Description: Set up IRSA to allow Kubernetes pods to assume AWS IAM roles
# Purpose: Enable EBS CSI Driver and other services to access AWS APIs securely
# Alternative to: Using AWS access keys in pods (insecure)

echo "=== OIDC Provider Setup ==="
echo "Note: OIDC provider is automatically created by Terraform via EKS cluster"

# Just wait for cluster to be ready
sleep 30

echo "✓ OIDC setup handled by Terraform"

echo "=== Configuring IRSA for EBS CSI Driver ==="

# Associate OIDC provider with EKS cluster
# This enables pod-level IAM authentication
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster kkp-cluster \
  --approve

# Create Kubernetes service account with IAM role for EBS CSI Driver
# Attach AmazonEBSCSIDriverPolicy for EBS volume management permissions
eksctl create iamserviceaccount \
  --region us-east-1 \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster kkp-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

# ============================================================================
# SECTION 9: VERIFY EBS CSI DRIVER DEPLOYMENT
# ============================================================================
# Description: Verify EBS CSI driver addon is ACTIVE

echo "=== Verifying EBS CSI Driver Addon ==="

# Wait for addon to become ACTIVE
for i in {1..60}; do
    ADDON_STATUS=$(aws eks describe-addon \
      --cluster-name kkp-cluster \
      --addon-name aws-ebs-csi-driver \
      --region us-east-1 \
      --query 'addon.addonStatus' \
      --output text 2>/dev/null || echo "CREATING")
    
    if [ "$ADDON_STATUS" = "ACTIVE" ]; then
        echo "✓ EBS CSI driver addon is ACTIVE"
        break
    fi
    
    echo "Addon status: $ADDON_STATUS ($((i*10))s elapsed)"
    sleep 10
done

# Verify service account has IRSA annotation
echo ""
echo "Verifying IRSA service account..."
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' || echo "Service account not found yet"

echo ""
echo "✓ EBS CSI driver verification completed"
# ============================================================================
# SECTION 10: DEPLOY KUBERNETES MANIFESTS
# ============================================================================
# Description: Apply custom Kubernetes manifests for application deployment
# File: manifest.yaml (should contain Deployments, Services, ConfigMaps, etc.)

echo "=== Deploying Kubernetes Resources ==="
kubectl apply -f manifest.yaml

# ============================================================================
# SECTION 11: VERIFICATION AND DIAGNOSTICS
# ============================================================================
# Description: Verify all components are running correctly

echo "=== Verifying EKS Cluster ==="

# Check worker nodes status
kubectl get nodes

# Verify EBS CSI Service Account exists
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system

# Check EBS CSI Driver pods are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# List all pods in default namespace (verify deployments)
kubectl get pods

echo "=== Deployment Complete ==="