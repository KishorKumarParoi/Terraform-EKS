# Cost Optimization Guide for EKS Terraform

This guide helps you reduce infrastructure costs while maintaining reliability and performance.

## 📊 Cost Breakdown (Current Configuration)

| Resource | Monthly Cost | % of Total |
|----------|-------------|-----------|
| EKS Cluster | $73.00 | 39% |
| EC2 (2x t3.medium) | $67.74 | 36% |
| Load Balancers (2x ELB) | $36.50 | 20% |
| Storage & Networking | $8.00 | 4% |
| **TOTAL** | **~$185** | **100%** |

---

## 🎯 Quick Cost Optimization (Save 35-50%)

### 1. Enable Spot Instances (60-70% EC2 Savings) ⭐⭐⭐

**Impact:** Reduces EC2 cost from $67.74 to ~$20/month (saves $47/month)

**Configuration:**

```hcl
# terraform.tfvars
enable_spot_instances = true
```

**Pros:**
- 60-70% cheaper than on-demand
- Scales automatically with cluster autoscaler

**Cons:**
- Can be interrupted (2-minute warning)
- Ideal for fault-tolerant workloads

**Best For:** Development, testing, batch jobs, non-critical production workloads

---

### 2. Use Smaller Instance Types (50% Compute Savings) ⭐⭐

**Impact:** Reduces EC2 cost from $67.74 to $30.35/month (saves $37/month)

**Configuration:**

```hcl
# Option A: Manual override
node_instance_types = ["t3.small"]

# Option B: Use cost optimization flag
use_smaller_instance_types = true
```

**Instance Type Comparison:**

| Type | vCPU | Memory | Price/Hour | Monthly (2 nodes) |
|------|------|--------|-----------|-----------------|
| t3.medium | 2 | 4GB | $0.0464 | $67.74 |
| t3.small | 2 | 2GB | $0.0208 | $30.35 |
| t3.micro | 2 | 1GB | $0.0104 | $15.17 |

**Before scaling down, verify:**
```bash
kubectl top nodes      # Check current resource usage
kubectl top pods       # Check pod resource requests
```

---

### 3. Reduce Node Count (50% EC2 Savings)

**Impact:** Reduces from 2 nodes to 1 node (saves $33.87/month)

**Configuration:**

```hcl
# terraform.tfvars
node_group_min_size     = 1
node_group_desired_size = 1
node_group_max_size     = 3  # Still scale up under load
```

**Risk Level:** ⚠️ MEDIUM
- Single point of failure
- No HA during node replacement
- Rolling updates will cause downtime

**Recommended For:** Development & staging only

---

### 4. Reduce Load Balancers (50% LB Savings) ⭐

**Impact:** Removes 1 ELB (saves $18.25/month)

**Option A: Use single Ingress controller with ALB**

```bash
# Instead of 2 Classic Load Balancers
helm install nginx-ingress ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace

# Deploy both services through ingress
```

**Option B: Use Network Load Balancer (More efficient)**

```yaml
kind: Service
metadata:
  name: app-nlb
spec:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
  ports:
    - port: 80
      targetPort: 8080
```

**Cost Comparison:**

| Load Balancer | Price/Hour | Monthly (1) | Monthly (2) |
|---------------|-----------|----------|----------|
| Classic ELB | $0.025 | $18.25 | $36.50 |
| ALB | $0.0225 | $16.43 | $32.86 |
| NLB | $0.0225 | $16.43 | $32.86 |

---

## 🚀 Combined Cost Optimization Strategies

### Strategy 1: Development/Test Environment
```hcl
# terraform.tfvars - DEV Configuration
enable_cost_optimization  = true              # All optimizations
use_smaller_instance_types = true            # t3.small
enable_spot_instances      = true            # Spot instances
node_group_min_size        = 1               # Single node
node_group_desired_size    = 1
cluster_log_types         = ["api"]          # Minimal logging
enable_detailed_logging    = false
```

**Expected Monthly Cost: $40-50**

```bash
# Deploy
make apply -var-file=dev.tfvars
```

---

### Strategy 2: Staging Environment (Balanced Cost & Reliability)
```hcl
# terraform.tfvars - STAGING Configuration
enable_spot_instances      = true            # Spot savings
use_smaller_instance_types = true            # t3.small
node_group_min_size        = 2               # 2 nodes for HA
node_group_desired_size    = 2
node_group_max_size        = 4
cluster_log_types         = ["api"]          # Minimal logging
```

**Expected Monthly Cost: $80-100**

---

### Strategy 3: Production Environment (Cost + Reliability)
```hcl
# terraform.tfvars - PROD Configuration
enable_spot_instances       = true
node_instance_types         = ["t3.medium"]  # Standard size
node_group_min_size         = 2
node_group_desired_size     = 3
node_group_max_size         = 6
cluster_log_types          = ["api", "audit"]  # Critical logs
enable_detailed_logging     = false
log_retention_days         = 7
```

**Expected Monthly Cost: $150-180**

---

## 📈 Cost Monitoring & Alerts

### View AWS Billing

```bash
# Get monthly cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-04-30 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Get daily EC2 costs
aws ce get-cost-and-usage \
  --time-period Start=2026-04-15,End=2026-04-21 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --filter file://ec2-filter.json \
  --group-by Type=DIMENSION,Key=INSTANCE_TYPE
```

### EC2 Filter (save as `ec2-filter.json`)

```json
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["Amazon Elastic Compute Cloud - Compute"]
  }
}
```

### Set Budget Alerts

```bash
# Create a $200/month budget alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget BudgetName=EKS-Monthly,\
BudgetLimit={Amount=200,Unit=USD},\
TimeUnit=MONTHLY,\
BudgetType=COST \
  --notifications-with-subscribers \
  NotificationWithSubscribers={Notification={NotificationType=ACTUAL,ComparisonOperator=GREATER_THAN,Threshold=90,ThresholdType=PERCENTAGE},Subscribers=[{SubscriptionType=EMAIL,Address=your-email@example.com}]}
```

---

## 💡 Advanced Cost Optimization

### 1. Use Karpenter (Better than Cluster Autoscaler)

```bash
# Karpenter can consolidate nodes more efficiently
helm repo add karpenter https://charts.karpenter.sh
helm install karpenter karpenter/karpenter \
  -n karpenter --create-namespace \
  --set settings.aws.clusterName=kkp-cluster \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT:role/KarpenterControllerRole
```

**Savings:** 20-30% additional savings through better bin packing

---

### 2. Use Reserved Instances (30% Savings for 1-Year Commitment)

```bash
# For production workloads with predictable load
aws ec2 describe-reserved-instances-offerings \
  --filters "Name=instance-type,Values=t3.medium" \
  --region us-east-1 \
  --query 'ReservedInstancesOfferings[0:5]'
```

**Comparison:**
- On-demand: $0.0464/hour
- 1-year RI: $0.0345/hour (26% savings)
- 3-year RI: $0.0276/hour (40% savings)

---

### 3. Migrate MySQL to RDS

**Current Cost:** MySQL pod consumes node resources (~0.5 nodes)

**RDS Alternative:**
- db.t3.micro: Free for 12 months, then $10-15/month
- Managed backups, HA, scaling built-in
- Frees up node for application workloads

**Configuration:**

```bash
# Deploy RDS separately
module "rds_mysql" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "kkp-mysql"
  engine     = "mysql"
  engine_version = "8.0"
  family     = "mysql8.0"
  major_engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage = 20
  storage_encrypted = true
}
```

---

## 🔧 Terraform Commands for Cost Optimization

```bash
# Apply with cost optimization enabled
make apply -var='enable_cost_optimization=true'

# Or with specific variables
terraform apply \
  -var="enable_spot_instances=true" \
  -var="node_instance_types=[\"t3.small\"]" \
  -var="cluster_log_types=[\"api\"]"

# Check what would change
terraform plan -var='enable_spot_instances=true'
```

---

## ✅ Cost Optimization Checklist

- [ ] Enable Spot instances for non-critical workloads
- [ ] Right-size instance types based on actual usage
- [ ] Reduce log retention for non-critical logs
- [ ] Consolidate load balancers to single ingress
- [ ] Set up CloudWatch billing alerts
- [ ] Monitor kubectl resource usage regularly
- [ ] Delete unused resources (PVCs, services, etc.)
- [ ] Consider Reserved Instances for stable production
- [ ] Evaluate RDS for managed databases
- [ ] Use Fargate for cost-sensitive workloads

---

## 📊 Savings Summary

| Optimization | Savings | Risk | Implementation |
|------------|---------|------|-----------------|
| Spot Instances | $47/mo (25%) | Low | Easy |
| Smaller Instance Types | $37/mo (20%) | Medium | Easy |
| Reduce Node Count | $34/mo (18%) | High | Easy |
| Consolidate LBs | $18/mo (10%) | Low | Medium |
| Reduce Logging | $3/mo (1%) | Low | Easy |
| **All Combined** | **$139/mo (75%)** | Variable | Complex |

---

## 🎯 Recommended Path

**Week 1:**
```hcl
enable_spot_instances = true          # Save $47/month immediately
```

**Week 2:**
```hcl
use_smaller_instance_types = true     # Save additional $37/month
```

**Week 3:**
```hcl
# Consolidate to single ingress controller
# Save $18/month on load balancers
```

**Month 2+:**
```hcl
# Migrate MySQL to RDS
# Frees node resources for applications
```

**Result:** ~$100/month instead of $185/month (46% savings!)

---

## 📚 References

- [AWS Compute Optimizer](https://aws.amazon.com/compute-optimizer/)
- [AWS EC2 Spot Instances](https://aws.amazon.com/ec2/spot/)
- [AWS Reserved Instances](https://aws.amazon.com/ec2/reserved-instances/)
- [Karpenter Documentation](https://karpenter.sh/)
- [EKS Best Practices Guide - Cost Optimization](https://aws.github.io/aws-eks-best-practices/cost_optimization/)

---

**Last Updated:** April 21, 2026
