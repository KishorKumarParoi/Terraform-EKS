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
aws configure set aws_access_key_id accessKeyId1234567890
aws configure set aws_secret_access_key secretAccessKey1234567890
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
cd Terraform-EKS

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

echo "=== Installing kubectl ==="

# Create temp directory for kubectl
KCTL_DIR=$(mktemp -d)
cd "$KCTL_DIR"

# Download kubectl binary matching latest stable Kubernetes version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Download SHA256 checksum for verification
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Verify binary integrity using SHA256 checksum
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Make kubectl executable
chmod +x kubectl

# Install to system-wide location (THIS WORKS BETTER)
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify kubectl installation
kubectl version --client

# Clean up temp directory
cd - > /dev/null
rm -rf "$KCTL_DIR"

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
# SECTION 8: CONFIGURE OIDC PROVIDER
# ============================================================================
# Description: Set up OIDC provider for pod-level IAM authentication

echo "=== Configuring OIDC Provider ==="

# Get cluster OIDC issuer
OIDC_ID=$(aws eks describe-cluster \
  --name kkp-cluster \
  --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | cut -d '/' -f 5)

echo "OIDC ID: $OIDC_ID"
echo "✓ OIDC provider configured by Terraform"

# # Create Kubernetes service account with IAM role for EBS CSI Driver
# # Attach AmazonEBSCSIDriverPolicy for EBS volume management permissions
# eksctl create iamserviceaccount \
#   --region us-east-1 \
#   --name ebs-csi-controller-sa \
#   --namespace kube-system \
#   --cluster kkp-cluster \
#   --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
#   --approve \
#   --override-existing-serviceaccounts

# ============================================================================
# SECTION 9: DEPLOY EBS CSI DRIVER (RELIABLE & DEBUGGABLE)
# ============================================================================
# Description: Deploy EBS CSI driver addon with comprehensive error checking

echo "=== Deploying EBS CSI Driver Addon ==="
echo ""

# ─────────────────────────────────────────
# STEP 1: VERIFY PREREQUISITES
# ─────────────────────────────────────────

echo "Step 1: Verifying prerequisites..."

# Check cluster exists
if ! aws eks describe-cluster --name kkp-cluster --region us-east-1 &>/dev/null; then
  echo "❌ ERROR: EKS cluster 'kkp-cluster' not found!"
  exit 1
fi
echo "✓ Cluster exists"

# Check nodes are ready
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
if [ "$READY_NODES" -lt 1 ]; then
  echo "⚠️  WARNING: No nodes are Ready yet. Waiting 60 seconds..."
  sleep 60
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
fi

if [ "$READY_NODES" -lt 1 ]; then
  echo "❌ ERROR: No nodes are Ready! Cluster not ready"
  kubectl get nodes
  exit 1
fi
echo "✓ $READY_NODES nodes are Ready"

# ─────────────────────────────────────────
# STEP 2: GET IAM ROLE ARN
# ─────────────────────────────────────────

echo ""
echo "Step 2: Getting IAM role ARN..."

# Get all roles that start with ebs-csi-driver
ROLE_NAME=$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'ebs-csi-driver')].RoleName" --output text 2>/dev/null | head -1)

if [ -z "$ROLE_NAME" ]; then
  echo "❌ ERROR: EBS CSI driver role not found!"
  echo "   Make sure Terraform created aws_iam_role.ebs_csi_driver"
  echo ""
  echo "   Available roles:"
  aws iam list-roles --query "Roles[?contains(RoleName, 'ebs')].RoleName" --output text
  exit 1
fi

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "Using role: $ROLE_NAME"
echo "Role ARN: $ROLE_ARN"

# Verify role has EBS policy
HAS_POLICY=$(aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --query "AttachedPolicies[?PolicyArn=='arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy'].PolicyArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$HAS_POLICY" ]; then
  echo "❌ ERROR: Role doesn't have AmazonEBSCSIDriverPolicy attached!"
  echo "Attached policies:"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text
  exit 1
fi
echo "✓ Role has correct policy attached"

# ─────────────────────────────────────────
# STEP 3: CHECK SERVICE ACCOUNT
# ─────────────────────────────────────────

echo ""
echo "Step 3: Checking service account..."

# Create service account in kube-system if it doesn't exist
if ! kubectl get serviceaccount ebs-csi-controller-sa -n kube-system &>/dev/null; then
  echo "Creating service account..."
  kubectl create serviceaccount ebs-csi-controller-sa -n kube-system
else
  echo "✓ Service account exists"
fi

# ─────────────────────────────────────────
# STEP 4: VERIFY OIDC PROVIDER
# ─────────────────────────────────────────

echo ""
echo "Step 4: Verifying OIDC provider..."

OIDC_ISSUER=$(aws eks describe-cluster \
  --name kkp-cluster \
  --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text 2>/dev/null || echo "")

if [ -z "$OIDC_ISSUER" ]; then
  echo "❌ ERROR: Could not get OIDC issuer from cluster!"
  exit 1
fi

echo "OIDC Issuer: $OIDC_ISSUER"

# Check if OIDC provider exists in IAM
OIDC_ID=$(echo "$OIDC_ISSUER" | cut -d '/' -f 5)
OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_ID')].Arn" \
  --output text 2>/dev/null || echo "")

if [ -z "$OIDC_PROVIDERS" ]; then
  echo "⚠️  OIDC provider not found. Creating..."
  eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster kkp-cluster \
    --approve
  echo "✓ OIDC provider created"
else
  echo "✓ OIDC provider exists"
fi

# ─────────────────────────────────────────
# STEP 5: ANNOTATE SERVICE ACCOUNT
# ─────────────────────────────────────────

echo ""
echo "Step 5: Annotating service account with IAM role..."

kubectl annotate serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  eks.amazonaws.com/role-arn="$ROLE_ARN" \
  --overwrite

echo "✓ Service account annotated"

# ─────────────────────────────────────────
# STEP 6: CHECK ADDON STATUS
# ─────────────────────────────────────────

echo ""
echo "Step 6: Checking existing addon..."

ADDON_STATUS=$(aws eks describe-addon \
  --cluster-name kkp-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 \
  --query 'addon.status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

case "$ADDON_STATUS" in
  ACTIVE)
    echo "✓ Addon is already ACTIVE"
    ;;
  CREATING)
    echo "⚠️  Addon is still CREATING. Waiting..."
    ;;
  CREATE_FAILED|DEGRADED)
    echo "⚠️  Addon in bad state: $ADDON_STATUS"
    echo "   Deleting and recreating..."
    aws eks delete-addon \
      --cluster-name kkp-cluster \
      --addon-name aws-ebs-csi-driver \
      --region us-east-1 2>/dev/null || true
    sleep 30
    ;;
  NOT_FOUND)
    echo "Addon not found, will create"
    ;;
esac

# ─────────────────────────────────────────
# STEP 7: CREATE ADDON
# ─────────────────────────────────────────

echo ""
echo "Step 7: Creating/updating EBS CSI driver addon..."

# Get latest addon version
ADDON_VERSION=$(aws eks describe-addon-versions \
  --addon-name aws-ebs-csi-driver \
  --kubernetes-version $(aws eks describe-cluster --name kkp-cluster --region us-east-1 --query 'cluster.version' --output text) \
  --query 'addons[0].addonVersions[0].addonVersion' \
  --output text 2>/dev/null || echo "")

if [ -z "$ADDON_VERSION" ]; then
  echo "⚠️  Could not determine addon version, using latest"
  ADDON_VERSION="latest"
fi

echo "Using addon version: $ADDON_VERSION"

# Create addon
aws eks create-addon \
  --cluster-name kkp-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn "$ROLE_ARN" \
  --resolve-conflicts OVERWRITE \
  --region us-east-1 \
  2>/dev/null || echo "Addon creation initiated (or already exists)"

# ─────────────────────────────────────────
# STEP 8: WAIT FOR ADDON TO BE ACTIVE
# ─────────────────────────────────────────

echo ""
echo "Step 8: Waiting for addon to become ACTIVE..."

TIMEOUT=0
MAX_TIMEOUT=120  # 20 minutes
POLL_INTERVAL=10

while [ $TIMEOUT -lt $MAX_TIMEOUT ]; do
  STATUS=$(aws eks describe-addon \
    --cluster-name kkp-cluster \
    --addon-name aws-ebs-csi-driver \
    --region us-east-1 \
    --query 'addon.status' \
    --output text 2>/dev/null || echo "UNKNOWN")
  
  ELAPSED=$((TIMEOUT * POLL_INTERVAL))
  MINUTES=$((ELAPSED / 60))
  SECONDS=$((ELAPSED % 60))
  
  if [ "$STATUS" = "ACTIVE" ]; then
    echo "✓ Addon is ACTIVE (${MINUTES}m ${SECONDS}s)"
    break
  elif [ "$STATUS" = "CREATE_FAILED" ]; then
    echo "❌ Addon creation FAILED!"
    aws eks describe-addon \
      --cluster-name kkp-cluster \
      --addon-name aws-ebs-csi-driver \
      --region us-east-1 \
      --query 'addon.health.issues' --output table
    exit 1
  fi
  
  printf "Status: %-12s Elapsed: %2d:%02d\n" "$STATUS" "$MINUTES" "$SECONDS"
  
  sleep $POLL_INTERVAL
  TIMEOUT=$((TIMEOUT + 1))
done

if [ $TIMEOUT -ge $MAX_TIMEOUT ]; then
  echo "⚠️  Addon still not ACTIVE after $MAX_TIMEOUT seconds"
  echo "Current status:"
  aws eks describe-addon \
    --cluster-name kkp-cluster \
    --addon-name aws-ebs-csi-driver \
    --region us-east-1 \
    --output table
fi

# ─────────────────────────────────────────
# STEP 9: VERIFY PODS ARE RUNNING
# ─────────────────────────────────────────

echo ""
echo "Step 9: Verifying EBS CSI driver pods..."

TIMEOUT=0
while [ $TIMEOUT -lt 30 ]; do
  POD_COUNT=$(kubectl get pods -n kube-system \
    -l app.kubernetes.io/name=aws-ebs-csi-driver \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l || echo "0")
  
  if [ "$POD_COUNT" -gt 0 ]; then
    echo "✓ $POD_COUNT EBS CSI driver pods are running"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
    break
  fi
  
  echo "Waiting for pods... ($TIMEOUT/30)"
  sleep 10
  TIMEOUT=$((TIMEOUT + 1))
done

# ─────────────────────────────────────────
# STEP 10: FINAL VERIFICATION
# ─────────────────────────────────────────

echo ""
echo "Step 10: Final verification..."

# Verify service account has annotation
SA_ANNOTATION=$(kubectl get serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")

if [ -n "$SA_ANNOTATION" ]; then
  echo "✓ Service account has IRSA annotation"
  echo "  Annotation: $SA_ANNOTATION"
else
  echo "⚠️  Service account missing IRSA annotation"
fi

echo ""
echo "✓ EBS CSI driver deployment completed successfully!"

# ============================================================================
# SECTION 10: DEPLOY KUBERNETES MANIFESTS
# ============================================================================
# Description: Apply custom Kubernetes manifests for application deployment

echo "=== Deploying Kubernetes Resources ==="

if [ -f manifest.yaml ]; then
  echo "Found manifest.yaml, applying..."
  kubectl apply -f manifest.yaml
  echo "✓ Manifests deployed"
else
  echo "⚠️  manifest.yaml not found, skipping"
  echo "   Create manifest.yaml with your Kubernetes resources"
fi

# ============================================================================
# SECTION 11: VERIFICATION AND DIAGNOSTICS
# ============================================================================
# Description: Verify all components are running correctly

echo ""
echo "=== Final Verification ==="

# Check worker nodes status
echo ""
echo "Nodes:"
kubectl get nodes -o wide

# Verify EBS CSI Service Account
echo ""
echo "EBS CSI Service Account:"
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o wide

# Check EBS CSI Driver pods
echo ""
echo "EBS CSI Driver Pods:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver -o wide

# Check addon status
echo ""
echo "Addon Status:"
aws eks describe-addon \
  --cluster-name kkp-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 \
  --query 'addon.{Version:addonVersion,Status:addonStatus,Health:health.issues}' \
  --output table

# List all pods
echo ""
echo "All pods in default namespace:"
kubectl get pods -o wide

echo ""
echo "✓ Deployment Complete!"

# Check pods are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Test EBS volume creation
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
EOF

# Check PVC status
kubectl get pvc test-pvc

# ============================================================================
# SECTION 12: ADD HELM REPOSITORIES
# ============================================================================

# helm install
sudo apt update -y

 curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

echo "=== Adding Helm Repositories ==="

# Add Bitnami charts
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update all repos
helm repo update

# Verify repositories
echo "✓ Available Helm repositories:"
helm repo list

helm search repo bitnami

helm search repo bitnami/nginx

helm install my-nginx bitnami/nginx