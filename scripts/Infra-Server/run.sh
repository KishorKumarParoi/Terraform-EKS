#!/bin/bash

################################################################################
# TERRAFORM + EKS + KUBECTL AUTOMATED DEPLOYMENT SCRIPT
# Purpose: Complete setup of AWS infrastructure with Terraform and Kubernetes
# Prerequisites: Ubuntu/Debian system with sudo access
################################################################################

# ============================================================================
# IMPORTANT REQUIREMENTS
# ============================================================================
# Before running this script, ensure:
#
# 1. AWS CREDENTIALS are configured
#    Option A: Run 'aws configure' and enter your AWS keys
#    Option B: Set environment variables:
#       export AWS_ACCESS_KEY_ID="your-key"
#       export AWS_SECRET_ACCESS_KEY="your-secret"
#       export AWS_DEFAULT_REGION="us-east-1"
#
# 2. TERRAFORM FILES exist at:
#    /Users/kishorkumarparoi/Desktop/DevOps/Mega-Project-Terraform/Terraform/
#    Should contain: main.tf, variable.tf, output.tf, addons.tf, versions.tf, etc.
#
# 3. INTERNET CONNECTION is available
#
# USAGE:
#   sudo bash run.sh
#
# TIMING:
#   This script typically takes 15-20 minutes to complete
#   (EKS cluster creation is the longest step)
#
# TROUBLESHOOTING:
#   If script fails:
#   1. Check AWS credentials: aws sts get-caller-identity
#   2. Check Terraform files: ls /Users/kishorkumarparoi/Desktop/DevOps/Mega-Project-Terraform/Terraform/
#   3. Check AWS quota: aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
#
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable
# Description: Install AWS CLI v2 and configure credentials for AWS access

sudo apt update -y

echo "=== Installing AWS CLI v2 ==="
# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
  echo "✓ AWS CLI is already installed"
  aws --version
else
  echo "Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  sudo apt install unzip -y
  unzip awscliv2.zip
  sudo ./aws/install
  rm -f awscliv2.zip
  echo "✓ AWS CLI installed"
fi

# Check if AWS credentials are already configured
echo ""
echo "=== Checking AWS Credentials ==="
if aws sts get-caller-identity &>/dev/null; then
  echo "✓ AWS credentials are already configured"
  aws sts get-caller-identity --output table
else
  echo "⚠️  AWS credentials not configured. Please configure them:"
  echo ""
  echo "Run: aws configure"
  echo "  - AWS Access Key ID: [your-access-key]"
  echo "  - AWS Secret Access Key: [your-secret-key]"
  echo "  - Default region: us-east-1"
  echo "  - Default output format: json"
  echo ""
  exit 1
fi

# ============================================================================
# SECTION 2: NAVIGATE TO TERRAFORM DIRECTORY
# ============================================================================
# Description: Navigate to the Terraform configuration directory

echo "=== Navigating to Terraform Directory ==="
git clone https://github.com/KishorKumarParoi/Terraform-EKS.git
TERRAFORM_DIR="Terraform-EKS/Terraform-Advanced"

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "❌ ERROR: Terraform directory not found at $TERRAFORM_DIR"
  echo "Please ensure Terraform files exist in that location"
  exit 1
fi

cd "$TERRAFORM_DIR"
echo "✓ Changed to directory: $(pwd)"
echo "✓ Terraform files found:"
ls -1 *.tf 2>/dev/null | head -5

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

# Optional: Remove resource if it exists from previous run (ignore if not found)
echo "Initializing Terraform state..."
terraform state rm aws_eks_addon.ebs_csi_driver 2>/dev/null || echo "No previous addon state to remove"

# Initialize Terraform
echo "Running: terraform init"
terraform init

# Show execution plan
echo "Running: terraform plan"
terraform plan -out=tfplan

# Apply changes automatically
echo "Running: terraform apply (this may take 15-20 minutes)"
terraform apply tfplan

# Clean up plan file (optional)
rm -f tfplan

echo ""
if [ $? -eq 0 ]; then
  echo "✓ Terraform apply completed successfully"
else
  echo "❌ Terraform apply failed! Please check the errors above"
  exit 1
fi

# Verify cluster was created
echo ""
echo "=== Verifying EKS Cluster Creation ==="
CLUSTER_EXISTS=$(aws eks describe-cluster --name kkp-cluster --region us-east-1 --query 'cluster.name' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_EXISTS" = "kkp-cluster" ]; then
  echo "✓ EKS cluster 'kkp-cluster' created successfully"
  aws eks describe-cluster --name kkp-cluster --region us-east-1 \
    --query 'cluster.{Name:name, Status:status, Version:version, Endpoint:endpoint}' \
    --output table
else
  echo "❌ ERROR: EKS cluster 'kkp-cluster' was not created!"
  echo "Please check Terraform logs above and try again"
  exit 1
fi

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

echo "=== Deploying Kubernetes Manifests Resources ==="

ls
cd ..
cd Manifest

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

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          DEPLOYMENT SUMMARY                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ Terraform Infrastructure:   DEPLOYED"
echo "✓ EKS Cluster:                CREATED (kkp-cluster)"
echo "✓ kubectl:                    CONFIGURED"
echo "✓ eksctl:                     INSTALLED"
echo "✓ EBS CSI Driver:             DEPLOYED"
echo "✓ Kubernetes Nodes:           READY"
echo ""

# ============================================================================
# SECTION 12: ADD HELM REPOSITORIES
# ============================================================================

# helm install
sudo apt update -y

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

# Verify Helm installation
helm version

# error checking helm version
if [ $? -eq 0 ]; then
  echo "✓ Helm installed successfully"
else
  echo "❌ Helm installation failed"
  exit 1
fi

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

echo "=== Installing Metrics Server ==="

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server \
  -n kube-system

# Wait for deployment
kubectl rollout status deployment/metrics-server -n kube-system

echo "✓ Metrics Server installed"
kubectl top node

# helm uninstall my-nginx

# ============================================================================
# SECTION 13: CREATE KUBERNETES RBAC AND SERVICE ACCOUNT MANIFESTS
# ============================================================================
# Description: Create separate YAML files for namespace, service account, role, and rolebinding

# echo ""
# echo "=== Creating Kubernetes RBAC Manifests ==="

# # Create directory for Kubernetes manifests
# mkdir -p ~/kubernetes-manifests

# # 1. Create Namespace file
# cat > ~/kubernetes-manifests/01-namespace.yaml <<'EOF'
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: webapps
#   labels:
#     name: webapps
# EOF
# echo "✓ Created: ~/kubernetes-manifests/01-namespace.yaml"

# # 2. Create ServiceAccount file
# cat > ~/kubernetes-manifests/02-serviceaccount.yaml <<'EOF'
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: jenkins
#   namespace: webapps
#   labels:
#     app: jenkins
# EOF
# echo "✓ Created: ~/kubernetes-manifests/02-serviceaccount.yaml"

# # 3. Create Role file
# cat > ~/kubernetes-manifests/03-role.yaml <<'EOF'
# apiVersion: rbac.authorization.k8s.io/v1
# kind: Role
# metadata:
#   name: jenkins-role
#   namespace: webapps
#   labels:
#     app: jenkins
# rules:
#   # Permissions for core API resources
#   - apiGroups: [""]
#     resources:
#       - secrets
#       - configmaps
#       - persistentvolumeclaims
#       - services
#       - pods
#     verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]

#   # Permissions for apps API group
#   - apiGroups: ["apps"]
#     resources:
#       - deployments
#       - replicasets
#       - statefulsets
#     verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]

#   # Permissions for networking API group
#   - apiGroups: ["networking.k8s.io"]
#     resources:
#       - ingresses
#     verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]

#   # Permissions for autoscaling API group
#   - apiGroups: ["autoscaling"]
#     resources:
#       - horizontalpodautoscalers
#     verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
# EOF
# echo "✓ Created: ~/kubernetes-manifests/03-role.yaml"

# # 4. Create RoleBinding file
# cat > ~/kubernetes-manifests/04-rolebinding.yaml <<'EOF'
# apiVersion: rbac.authorization.k8s.io/v1
# kind: RoleBinding
# metadata:
#   name: jenkins-rolebinding
#   namespace: webapps
#   labels:
#     app: jenkins
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: Role
#   name: jenkins-role
# subjects:
#   - kind: ServiceAccount
#     name: jenkins
#     namespace: webapps
# EOF
# echo "✓ Created: ~/kubernetes-manifests/04-rolebinding.yaml"

# # 5. Create ClusterRole file
# cat > ~/kubernetes-manifests/05-clusterrole.yaml <<'EOF'
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: jenkins-cluster-role
# rules:
#   # Permissions for persistentvolumes
#   - apiGroups: [""]
#     resources:
#       - persistentvolumes
#     verbs: ["get", "list", "watch", "create", "update", "delete"]
#   # Permissions for storageclasses
#   - apiGroups: ["storage.k8s.io"]
#     resources:
#       - storageclasses
#     verbs: ["get", "list", "watch", "create", "update", "delete"]
#   # Permissions for ClusterIssuer (cert-manager)
#   - apiGroups: ["cert-manager.io"]
#     resources:
#       - clusterissuers
#     verbs: ["get", "list", "watch", "create", "update", "delete"]
# EOF
# echo "✓ Created: ~/kubernetes-manifests/05-clusterrole.yaml"

# # 6. Create ClusterRoleBinding file
# cat > ~/kubernetes-manifests/06-clusterrolebinding.yaml <<'EOF'
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: jenkins-cluster-rolebinding
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: jenkins-cluster-role
# subjects:
#   - kind: ServiceAccount
#     name: jenkins
#     namespace: webapps
# EOF
# echo "✓ Created: ~/kubernetes-manifests/06-clusterrolebinding.yaml"

# # 7. Create Secret file for service account token
# cat > ~/kubernetes-manifests/07-secret.yaml <<'EOF'
# apiVersion: v1
# kind: Secret
# type: kubernetes.io/service-account-token
# metadata:
#   name: jenkins-token
#   namespace: webapps
#   annotations:
#     kubernetes.io/service-account.name: jenkins
# EOF
# echo "✓ Created: ~/kubernetes-manifests/07-secret.yaml"

# # Apply all manifests in order
# echo ""
# echo "=== Applying RBAC Manifests ==="
# kubectl apply -f ~/kubernetes-manifests/01-namespace.yaml
# kubectl apply -f ~/kubernetes-manifests/02-serviceaccount.yaml
# kubectl apply -f ~/kubernetes-manifests/03-role.yaml
# kubectl apply -f ~/kubernetes-manifests/04-rolebinding.yaml
# kubectl apply -f ~/kubernetes-manifests/05-clusterrole.yaml
# kubectl apply -f ~/kubernetes-manifests/06-clusterrolebinding.yaml
# kubectl apply -f ~/kubernetes-manifests/07-secret.yaml

# if [ $? -eq 0 ]; then
#   echo "✓ All RBAC manifests applied successfully"
# else
#   echo "❌ Failed to apply some manifests"
#   exit 1
# fi

# # Verify all resources
# echo ""
# echo "=== Verifying RBAC Resources ==="

# echo ""
# echo "Namespace:"
# kubectl get namespace webapps

# echo ""
# echo "Service Account:"
# kubectl get serviceaccount jenkins -n webapps

# echo ""
# echo "Role:"
# kubectl get role jenkins-role -n webapps

# echo ""
# echo "RoleBinding:"
# kubectl get rolebinding jenkins-rolebinding -n webapps

# echo ""
# echo "ClusterRole:"
# kubectl get clusterrole jenkins-cluster-role

# echo ""
# echo "ClusterRoleBinding:"
# kubectl get clusterrolebinding jenkins-cluster-rolebinding

# echo ""
# echo "Secret:"
# kubectl get secret jenkins-token -n webapps

# echo ""
# echo "=== RBAC Files Location ==="
# ls -lah ~/kubernetes-manifests/

# echo ""
# echo "=== Service Account Token ==="
# kubectl get secret jenkins-token -n webapps -o jsonpath='{.data.token}' | base64 -d | head -c 50
# echo "..."
# echo ""
# echo "✓ All RBAC resources created and verified successfully!"


# # Save secret description in base64
# echo ""
# echo "=== Saving Secret Description in Base64 ==="

# # Method 1: Save full description to file (base64 encoded)
# kubectl describe secret jenkins-token -n webapps | base64 > ~/kubernetes-manifests/jenkins-token-description.b64
# echo "✓ Saved: ~/kubernetes-manifests/jenkins-token-description.b64"

# # Method 2: Decode to view
# echo ""
# echo "Base64 Encoded Secret Description:"
# cat ~/kubernetes-manifests/jenkins-token-description.b64

# # Method 3: View the actual secret token (already base64, decode it)
# echo ""
# echo "=== Jenkins Token (Decoded) ==="
# kubectl get secret jenkins-token -n webapps -o jsonpath='{.data.token}' | base64 -d

# # Method 4: Save token separately
# kubectl get secret jenkins-token -n webapps -o jsonpath='{.data.token}' | base64 -d > ~/kubernetes-manifests/jenkins-token.txt
# echo ""
# echo "✓ Token saved to: ~/kubernetes-manifests/jenkins-token.txt"

# # Method 5: Save entire secret as base64 YAML
# kubectl get secret jenkins-token -n webapps -o yaml | base64 > ~/kubernetes-manifests/jenkins-token-secret.yaml.b64
# echo "✓ Full secret saved: ~/kubernetes-manifests/jenkins-token-secret.yaml.b64"

# echo ""
# echo "=== Files Created ==="
# ls -lah ~/kubernetes-manifests/jenkins-token*

# git config --global user.email kishor.ruet.cse@gmail.com
# git config --global user.name Kishorkumarparoi

# cd ~/Boardgame
# mkdir -p k8s
# cp ~/kubernetes-manifests/*.yaml k8s/

# # Push to GitHub
# git add k8s/
# git commit -m "Add Kubernetes deployment manifests"
# git push origin main

# # Detailed view of all instances
# aws ec2 describe-instances \
#   --region us-east-1 \
#   --filters "Name=instance-state-name,Values=running" \
#   --query 'Reservations[*].Instances[*].[InstanceId, Tags[?Key==`Name`].Value|[0], InstanceType, PrivateIpAddress, PublicIpAddress, LaunchTime, State.Name]' \
#   --output table

#   # Show all EKS worker nodes with their EC2 instance details
# aws ec2 describe-instances \
#   --region us-east-1 \
#   --filters "Name=tag:eks:cluster-name,Values=kkp-cluster" \
#   --query 'Reservations[*].Instances[*].[InstanceId, InstanceType, PrivateIpAddress, PublicIpAddress, State.Name, LaunchTime, Tags[?Key==`Name`].Value|[0]]' \
#   --output table



# now go to jenkins and install these plugins:
# Pipeline stage view
# SonarQube Scanner 
# Docker Pipeline
# Kubernetes CLI 
# Maven Integration 
# Config File Provider 
# Pipeline Maven Integration 
# eclipse temurin installer
# webhook trigger 

# create sonar-server (jenkins system), sonarqube-webhook (sonarqub configuration),
# git cred, docker, sonar-token (jenkins credential)
# then setup maven, jdk, sonar-scanner in jenkins global tool configuration
# update pom.xml <distributionManagement> file with nexus maven releases and snapshots repository link
# write global config files adding 
# <servers>
    #  <server>
    #   <id>maven-releases</id>
    #   <username>admin</username>
    #   <password>admin123</password>
    # </server>
    
    #  <server>
    #   <id>maven-snapshots</id>
    #   <username>admin</username>
    #   <password>admin123</password>
    # </server>

    # <server>
    #   <id>maven-proxy-repo</id>
    #   <username>admin</username>
    #   <password>admin123</password>
    # </server>
# </servers>
# <mirrors>
  #   <mirror>
  #     <id>nexus</id>
  #     <mirrorOf>*</mirrorOf>
  #     <name>Human Readable Name for this Mirror.</name>
  #     <url> http://3.235.232.192:8081/repository/maven-proxy-repo/</url>
  #   </mirror>
# </mirrors>

# add sepereated bind credentials for git
# setup smtp gmail server
# generic webhook trigger for sonarqube-webhook
  # post content params:
    #  ref, $.ref, webhook-trigger secret text token cred
    # http://54.160.39.177:8080/generic-webhook-trigger/invoke?token=kishorparoi

# now write pipeline script 
# total cred: sonar-token, git, docker-cred, mail-cred, webhook-trigger

# scp -i /Users/kishorkumarparoi/Desktop/DevOps/kkp.pem -r ./k8s ubuntu@44.200.209.123:~/