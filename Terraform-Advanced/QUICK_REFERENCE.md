# Terraform-Advanced - Quick Reference & Troubleshooting

## 🔍 **Component Quick Reference**

### **VPC & Networking**

```
VPC CIDR: 10.0.0.0/16
├─ Subnet 1: 10.0.0.0/24 (AZ: us-east-1a)
├─ Subnet 2: 10.0.1.0/24 (AZ: us-east-1b)
└─ IGW: Provides internet connectivity (0.0.0.0/0 → IGW)

Total IPs available: 65,536
Per subnet: 256 IPs (248 usable after AWS reserves 5)
```

### **Security Groups**

```
Cluster SG (kkp-cluster-sg)
├─ INGRESS: Port 443 from Node SG (API server)
└─ EGRESS: All traffic (0.0.0.0/0)

Node SG (kkp-node-sg)
├─ INGRESS: All from VPC (10.0.0.0/16)
├─ INGRESS: All from Cluster SG
├─ INGRESS: SSH (22) if enabled
└─ EGRESS: All traffic (0.0.0.0/0)
```

### **Cluster Configuration**

```
Cluster Name:     kkp-cluster
Kubernetes:       1.29
Control Plane:    Managed by AWS (3 nodes, multi-AZ)
Cost:             $0.10/hour = ~$73/month
Encryption:       KMS (etcd secrets)
Logging:          CloudWatch (api logs only by default)
Endpoints:        Public + Private
```

### **Node Group Configuration**

```
Instance Type:    t3.medium (2 vCPU, 4 GB RAM)
Min Nodes:        2
Desired Nodes:    2
Max Nodes:        5
Cost:             $0.0464/hour = ~$34/node/month
Disk Size:        50 GB
AMI:              Amazon EKS Optimized (auto-managed)
Auto Scaling:     Enabled
Spot Instances:   Optional (save 60-70%)
```

### **Addons**

```
1. EBS CSI Driver
   - Enables persistent volumes (PVC)
   - Creates EBS volumes on demand
   - Cost: Included with EBS usage

2. VPC CNI
   - Assigns IPs from VPC CIDR to pods
   - Direct VPC networking (no overlay)
   - Cost: Included in EC2 cost

3. CoreDNS
   - Service discovery
   - DNS: service-name.namespace.svc.cluster.local
   - Cost: Included in cluster cost

4. kube-proxy
   - Load balancing between pods
   - iptables rule management
   - Cost: Included in cluster cost
```

---

## 📊 **Resource Dependencies**

```
AWS Account (Region: us-east-1)
     ↓
VPC (10.0.0.0/16)
     ├─ Subnets (10.0.0.0/24, 10.0.1.0/24)
     ├─ Internet Gateway
     ├─ Route Table
     ├─ Security Groups (2)
     └─ All Route Table Associations
          ↓
     IAM Roles (3)
     ├─ Cluster Role
     ├─ Node Role
     └─ Addon Roles (EBS CSI, VPC CNI)
          ↓
     KMS Keys (2)
     ├─ EKS etcd key
     └─ EBS key
          ↓
     EKS Cluster
          ├─ API Server
          ├─ etcd (encrypted)
          ├─ CloudWatch Logs
          └─ OIDC Provider
               ↓
          Node Group
          ├─ Auto Scaling Group
          ├─ Launch Template
          └─ 2-5 EC2 Instances
               ↓
          EKS Addons
          ├─ EBS CSI Driver
          ├─ VPC CNI
          ├─ CoreDNS
          └─ kube-proxy
```

---

## 🛠️ **Common Tasks & Commands**

### **Deployment**

```bash
# Step 1: Prepare
cd Terraform-Advanced
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # Edit for your needs

# Step 2: Initialize
terraform init

# Step 3: Validate
terraform validate

# Step 4: Review changes
terraform plan

# Step 5: Deploy
terraform apply

# Step 6: Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name kkp-cluster
kubectl cluster-info
```

### **Verify Deployment**

```bash
# Check cluster
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Check add-ons
kubectl get daemonsets -n kube-system
kubectl get deployment -n kube-system

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

### **Scale Cluster**

```bash
# Increase max nodes
terraform apply -var="node_group_max_size=10"

# Change instance type
terraform apply -var="node_instance_types=[\"t3.large\"]"

# Enable Spot instances
terraform apply -var="enable_spot_instances=true"
```

### **Destroy**

```bash
# See what will be deleted
terraform plan -destroy

# Delete everything
terraform destroy -auto-approve
```

---

## ⚠️ **Troubleshooting Guide**

### **Issue 1: Terraform Plan Shows Everything as "to be created"**

**Symptom:**
```
Plan: 50 to add, 0 to change, 0 to destroy
```

**Cause:** `.terraform` directory is missing or corrupted

**Solution:**
```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
terraform plan
```

---

### **Issue 2: "InvalidParameterException: An error occurred"**

**Symptom:**
```
Error: Error creating EKS Cluster: InvalidParameterException: 
Subnet arn:aws:ec2:us-east-1:... is not available
```

**Cause:** Subnet AZ doesn't have capacity or doesn't exist

**Solution:**
```bash
# Check available AZs
aws ec2 describe-availability-zones --region us-east-1

# Update terraform.tfvars
subnet_count = 2  # Use only available AZs
```

---

### **Issue 3: Nodes not joining cluster**

**Symptom:**
```
kubectl get nodes
# Shows 0 nodes or nodes in "NotReady" state
```

**Cause:** Security group or IAM role misconfiguration

**Solution:**
```bash
# Check node security group allows cluster SG
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check node IAM role has required policies
aws iam list-attached-role-policies --role-name kkp-cluster-node-group

# Check node logs
aws ec2 get-console-output --instance-id i-xxxxx --region us-east-1

# Check CloudFormation stack (created by node group)
aws cloudformation describe-stacks --stack-name eks-node-group-xxxxx
```

---

### **Issue 4: "PersistentVolumeClaim is pending"**

**Symptom:**
```
kubectl describe pvc my-pvc
Status: Pending
```

**Cause:** EBS CSI Driver not properly deployed

**Solution:**
```bash
# Check EBS CSI addon
kubectl get pods -n kube-system | grep ebs-csi

# If missing, check addon status
aws eks describe-addon --cluster-name kkp-cluster --addon-name aws-ebs-csi-driver

# Check IAM role attachment
aws iam get-role --role-name kkp-cluster-ebs-csi-driver

# Check service account annotation
kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml
# Should have: eks.amazonaws.com/role-arn annotation
```

---

### **Issue 5: Cannot pull images from ECR**

**Symptom:**
```
kubectl describe pod my-pod
# ImagePullBackOff or RegistryUnavailable
```

**Cause:** Node IAM role missing ECR permissions

**Solution:**
```bash
# Verify IAM policy
aws iam get-role-policy --role-name kkp-cluster-node-group --policy-name xxxxx

# Add required policy
aws iam attach-role-policy \
  --role-name kkp-cluster-node-group \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Recreate nodes
aws eks update-nodegroup-config \
  --cluster-name kkp-cluster \
  --nodegroup-name kkp-cluster-node-group \
  --scaling-config minSize=2,maxSize=5,desiredSize=2
```

---

### **Issue 6: Terraform destroy hangs**

**Symptom:**
```
Destroy will take 10+ minutes
Or shows: aws_internet_gateway: still destroying
```

**Cause:** Resources have dependencies or are in use

**Solution:**
```bash
# Cancel with Ctrl+C after 5 minutes
# Then clean up manually

# 1. Delete load balancers (if any)
aws elb describe-load-balancers --region us-east-1
aws elb delete-load-balancer --load-balancer-name xxxxx

# 2. Delete VPC endpoints (if any)
aws ec2 describe-vpc-endpoints --region us-east-1
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids ...

# 3. Try destroy again
terraform destroy -auto-approve
```

---

### **Issue 7: "for_each set includes values derived from resource attributes" (FIXED ✅)**

**What we fixed:**
```hcl
# ❌ BEFORE: for_each with dynamic data
for_each = toset([for asg in data.aws_autoscaling_groups.node_group.names : asg])

# ✅ AFTER: count with dynamic length
count = length(data.aws_autoscaling_groups.node_group.names)
```

**Why it was wrong:** `for_each` needs all keys at plan time, but ASG names are only known after nodes are created.

**Solution applied:** Changed to `count`, which can handle dynamic values.

---

## 📈 **Monitoring & Observability**

### **CloudWatch Logs**

```bash
# View cluster logs
aws logs tail /aws/eks/kkp-cluster/cluster

# Filter for errors
aws logs tail /aws/eks/kkp-cluster/cluster --filter-pattern "ERROR"

# Get last 100 lines
aws logs tail /aws/eks/kkp-cluster/cluster --max-items 100
```

### **Metrics**

```bash
# Get cluster metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_node_count \
  --dimensions Name=ClusterName,Value=kkp-cluster \
  --start-time 2026-04-21T00:00:00Z \
  --end-time 2026-04-22T00:00:00Z \
  --period 3600 \
  --statistics Average
```

---

## 🔐 **Security Best Practices**

### **1. Restrict Public API Endpoint**

```bash
# Edit cluster_endpoint_public_access_cidrs
terraform apply -var='cluster_endpoint_public_access_cidrs=["YOUR_IP/32"]'

# Or in terraform.tfvars
cluster_endpoint_public_access_cidrs = ["203.0.113.10/32"]
```

### **2. Enable All Logging**

```bash
# Change in terraform.tfvars
cluster_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]
```

### **3. Enforce IMDS v2**

Already enforced in node launch template (not exposed in UI)

### **4. RBAC**

```bash
# Create service accounts with least privilege
kubectl create serviceaccount my-app
kubectl create role my-app-role --verb=get,list --resource=pods
kubectl create rolebinding my-app-binding --role=my-app-role --serviceaccount=default:my-app
```

---

## 💡 **Performance Tips**

### **Pod IP Assignment**

```bash
# Check pod IPs are from VPC CIDR
kubectl get pods -A -o wide | grep -i 10.0

# Should show: 10.0.0.50, 10.0.1.25, etc.
# NOT: 172.17.x.x (that would be wrong)
```

### **DNS Resolution**

```bash
# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Should resolve to 172.20.0.1 (ClusterIP)
```

### **Load Balancer Performance**

```bash
# Check kube-proxy iptables rules
kubectl get svc
# Each service gets iptables rules on every node
```

---

## 📚 **Common Patterns**

### **Pattern 1: Spot Instances for Cost Savings**

```hcl
# terraform.tfvars
enable_spot_instances = true

# 60-70% cheaper but can be interrupted
# Good for: Batch jobs, non-critical workloads
```

### **Pattern 2: Multi-Cluster Setup**

```bash
# Create dev cluster
terraform apply -var-file=terraform.tfvars.dev -out=dev.tfplan

# Create prod cluster in same account (different VPC CIDR)
terraform apply -var-file=terraform.tfvars.prod -out=prod.tfplan
```

### **Pattern 3: Disaster Recovery**

```bash
# Store state in S3 with versioning
aws s3api put-bucket-versioning --bucket my-terraform-state --versioning-configuration Status=Enabled

# Backup state file daily
aws s3 sync . s3://my-terraform-state/daily-backup/
```

---

## 🎓 **Learning Exercises**

### **Exercise 1: Scale from 2 to 4 nodes**

```bash
# Update variable
terraform apply -var="node_group_desired_size=4"

# Verify
kubectl get nodes --watch
```

### **Exercise 2: Enable Spot instances**

```bash
# Update variable  
terraform apply -var="enable_spot_instances=true"

# Check node capacity_type
aws eks describe-nodegroup \
  --cluster-name kkp-cluster \
  --nodegroup-name kkp-cluster-node-group \
  --query 'nodegroup.capacityType'
```

### **Exercise 3: Create PVC and mount in pod**

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 10Gi

---

# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: busybox
    volumeMounts:
    - mountPath: "/data"
      name: myvolume
  volumes:
  - name: myvolume
    persistentVolumeClaim:
      claimName: my-data
```

```bash
kubectl apply -f pvc.yaml
kubectl apply -f pod.yaml
kubectl exec my-pod -- ls -la /data
```

---

## 📞 **Getting Help**

### **Check Terraform State**

```bash
# List all resources
terraform state list

# Inspect specific resource
terraform state show aws_eks_cluster.kkp

# Get all outputs
terraform output

# Get specific output
terraform output cluster_endpoint
```

### **AWS CLI Queries**

```bash
# Get cluster details
aws eks describe-cluster --name kkp-cluster --region us-east-1

# Get node group details
aws eks describe-nodegroup \
  --cluster-name kkp-cluster \
  --nodegroup-name kkp-cluster-node-group

# List all add-ons
aws eks list-addons --cluster-name kkp-cluster

# Check OIDC provider
aws iam list-open-id-connect-providers
```

---

## 🚀 **Next Steps**

1. Deploy the cluster with `terraform apply`
2. Configure kubectl with the provided output
3. Deploy a test application
4. Monitor logs and metrics
5. Try scaling and cost optimization
6. Deploy to production with prod configs
7. Set up backups and disaster recovery

---

**Remember:** Always test changes in dev/staging before applying to production!
