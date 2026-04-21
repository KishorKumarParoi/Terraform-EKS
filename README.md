```markdown
# Terraform EKS - Blue Green Deployment with Monitoring

A complete Infrastructure-as-Code solution for deploying a production-grade Kubernetes cluster on AWS with Blue-Green deployment strategy and comprehensive monitoring.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Installation & Deployment](#installation--deployment)
- [Blue-Green Deployment](#blue-green-deployment)
- [Monitoring & Observability](#monitoring--observability)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

This project provides:

- **Infrastructure as Code (IaC)**: Terraform automation for AWS EKS cluster provisioning
- **Blue-Green Deployment**: Zero-downtime application updates
- **Production-Ready Kubernetes**: RBAC, Network Policies, Pod Security
- **Complete Monitoring**: Prometheus, Grafana, and ELK stack integration
- **CI/CD Integration**: Jenkins pipelines for automated deployments
- **Container Registry**: Nexus integration for image management

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Cloud Platform | AWS |
| Kubernetes | EKS |
| IaC | Terraform |
| Container Registry | Docker + Nexus |
| CI/CD | Jenkins |
| Monitoring | Prometheus + Grafana |
| Logs | ELK Stack (Elasticsearch, Logstash, Kibana) |
| Code Quality | SonarQube |
| Database | MySQL 8 |
| Application | Spring Boot (BankApp) |

---

## 🏗️ Architecture

### Deployment Architecture

```
AWS EKS Cluster
├── Blue Environment (Current)
│   ├── BankApp Deployment (v1.0)
│   ├── MySQL StatefulSet
│   └── Monitoring Agents
├── Green Environment (Standby)
│   ├── BankApp Deployment (v2.0)
│   ├── MySQL StatefulSet
│   └── Monitoring Agents
├── Load Balancer (Routes to Active)
├── Persistent Storage (EBS)
└── Monitoring Stack
    ├── Prometheus
    ├── Grafana
    └── AlertManager
```

### Network Architecture

- **VPC**: Custom VPC with public/private subnets
- **Security Groups**: Strict ingress/egress rules
- **Network Policies**: Kubernetes native network segmentation
- **Service Mesh**: Ready for Istio integration
- **RBAC**: Role-based access control enabled

---

## 📋 Prerequisites

### Required Tools

```bash
# Terraform >= 1.0
terraform --version

# AWS CLI >= 2.0
aws --version

# kubectl >= 1.24
kubectl version --client

# Helm >= 3.0 (optional, for package management)
helm version
```

### AWS Requirements

- AWS Account with appropriate IAM permissions
- VPC and subnets configured
- AWS Access Keys configured
- Sufficient quota for EKS resources

### Verify Prerequisites

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Kubernetes connectivity (after deployment)
kubectl cluster-info
```

---

## 📁 Project Structure

```
Mega-Project-Terraform/
├── main.tf                 # Main Terraform configuration
├── variable.tf             # Variable definitions
├── output.tf               # Output definitions
├── README.md               # This file
│
├── Boardgame/              # Application code
│   ├── src/                # Java source code
│   ├── Dockerfile          # Container image definition
│   ├── pom.xml             # Maven dependencies
│   ├── Jenkinsfile         # CI/CD pipeline
│   └── k8s/                # Kubernetes manifests
│       ├── base/           # Base configurations
│       └── overlays/       # Environment-specific patches
│           ├── dev/        # Development environment
│           ├── staging/    # Staging environment
│           └── prod/       # Production environment
│
├── Manifest/               # Kubernetes manifests
│   └── manifest.yaml       # MySQL + BankApp deployment
│
├── RBAC/                   # Security configurations
│   └── rbac.md             # RBAC documentation
│
└── scripts/                # Automation scripts
    ├── Infra-Server/       # Infrastructure setup
    ├── Jenkins/            # Jenkins automation
    ├── Kubernetes/         # K8s operations
    ├── Sonarqube/          # Code quality setup
    ├── Nexus/              # Registry setup
    └── Data/               # Database migrations
```

---

## 🚀 Installation & Deployment

### Step 1: Clone and Navigate

```bash
cd /path/to/Mega-Project-Terraform
```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform working directory
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Step 3: Plan Infrastructure

```bash
# Review changes
terraform plan -out=tfplan

# Optional: Save to file for review
terraform plan -out=tfplan
cat tfplan
```

### Step 4: Apply Configuration

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly (requires approval)
terraform apply

# Note: This will take 10-15 minutes for EKS cluster creation
```

### Step 5: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region <aws-region>

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 6: Deploy Application

```bash
# Deploy using Kustomize
kubectl apply -k Boardgame/k8s/overlays/prod/

# Or deploy manifest directly
kubectl apply -f Manifest/manifest.yaml

# Verify deployments
kubectl get deployments
kubectl get pods
kubectl get svc
```

---

## 🔄 Blue-Green Deployment

### Concept

Blue-Green deployment allows zero-downtime updates by running two identical production environments:
- **Blue**: Current production environment
- **Green**: New version staged and tested

### Deployment Steps

#### 1. Verify Current (Blue) Status

```bash
# Check blue deployment
kubectl get deployment bankapp -n default
kubectl get pods -l app=bankapp

# Verify traffic routing
kubectl get svc bankapp-service
```

#### 2. Deploy New Version (Green)

```bash
# Create green deployment with new image
kubectl set image deployment/bankapp \
  bankapp=adijaiswal/bankapp:v2.0 \
  --record=true

# Wait for rollout to complete
kubectl rollout status deployment/bankapp -w

# Verify green deployment
kubectl get pods -l app=bankapp
```

#### 3. Run Tests on Green

```bash
# Get green pod IP
GREEN_POD=$(kubectl get pod -l app=bankapp -o jsonpath='{.items[0].status.podIP}')

# Test connectivity
curl -X GET http://$GREEN_POD:8080/health

# Run integration tests
./scripts/run-integration-tests.sh $GREEN_POD
```

#### 4. Switch Traffic from Blue to Green

```bash
# Option A: Update service selector
kubectl patch service bankapp-service \
  -p '{"spec":{"selector":{"version":"v2.0"}}}'

# Option B: Use ingress traffic splitting
kubectl patch ingress bankapp-ingress \
  --type merge -p '{"spec":{"rules":[{"http":{"paths":[{"path":"/","backend":{"serviceName":"bankapp-green","servicePort":8080}}]}}]}}'
```

#### 5. Monitor and Verify

```bash
# Check traffic metrics
kubectl top pods
kubectl logs -f deployment/bankapp

# Monitor application health
curl -X GET http://bankapp-service:80/metrics
```

#### 6. Rollback if Needed

```bash
# Immediate rollback to previous version
kubectl rollout undo deployment/bankapp

# Verify rollback
kubectl rollout status deployment/bankapp -w
```

### Kustomize Overlays for Blue-Green

```bash
# Deploy to dev environment
kubectl apply -k Boardgame/k8s/overlays/dev/

# Deploy to staging
kubectl apply -k Boardgame/k8s/overlays/staging/

# Deploy to production
kubectl apply -k Boardgame/k8s/overlays/prod/
```

---

## 📊 Monitoring & Observability

### Prometheus Setup

```bash
# Deploy Prometheus
kubectl apply -f scripts/monitoring/prometheus-deployment.yaml

# Access Prometheus
kubectl port-forward svc/prometheus 9090:9090
# Visit: http://localhost:9090
```

### Grafana Setup

```bash
# Deploy Grafana
kubectl apply -f scripts/monitoring/grafana-deployment.yaml

# Access Grafana
kubectl port-forward svc/grafana 3000:3000
# Visit: http://localhost:3000 (admin/admin)
```

### Key Metrics to Monitor

```
Application Metrics:
- http_requests_total
- http_request_duration_seconds
- application_errors_total

Kubernetes Metrics:
- container_memory_usage_bytes
- container_cpu_usage_seconds_total
- pod_network_io_bytes

Database Metrics:
- mysql_connections
- mysql_queries_total
- mysql_replication_lag
```

### ELK Stack for Logs

```bash
# Deploy Elasticsearch
kubectl apply -f scripts/monitoring/elasticsearch-deployment.yaml

# Deploy Logstash
kubectl apply -f scripts/monitoring/logstash-deployment.yaml

# Deploy Kibana
kubectl apply -f scripts/monitoring/kibana-deployment.yaml

# Access Kibana
kubectl port-forward svc/kibana 5601:5601
# Visit: http://localhost:5601
```

### SonarQube Code Quality

```bash
# Start SonarQube
./scripts/Sonarqube/run.sh

# Run code analysis
mvn sonar:sonar \
  -Dsonar.projectKey=bankapp \
  -Dsonar.sources=Boardgame/src/main/java \
  -Dsonar.host.url=http://localhost:9000
```

---

## 🔐 Security

### RBAC Configuration

```bash
# View configured roles
kubectl get roles -A

# View role bindings
kubectl get rolebindings -A

# Apply custom RBAC
kubectl apply -f RBAC/rbac.md
```

### Network Policies

```bash
# View network policies
kubectl get networkpolicies -A

# Apply network policies
kubectl apply -f Boardgame/k8s/base/12-networkpolicy.yaml
```

### Pod Security Policies

```bash
# Check pod security standards
kubectl label namespace default \
  pod-security.kubernetes.io/enforce=baseline

# View current labels
kubectl get ns -L pod-security.kubernetes.io/enforce
```

### Secrets Management

```bash
# View secrets
kubectl get secrets

# Decode secret value
kubectl get secret mysql-secret \
  -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d

# Rotate credentials
kubectl create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD=NewPassword \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 🔧 Common Operations

### Scale Application

```bash
# Scale replicas
kubectl scale deployment bankapp --replicas=5

# Auto-scaling with HPA
kubectl autoscale deployment bankapp \
  --min=2 --max=10 --cpu-percent=80
```

### View Logs

```bash
# Current logs
kubectl logs deployment/bankapp

# Tail logs
kubectl logs -f deployment/bankapp

# Previous pod logs (crashed)
kubectl logs deployment/bankapp --previous

# All pods in deployment
kubectl logs -l app=bankapp
```

### Execute Commands in Pod

```bash
# Connect to pod
kubectl exec -it <pod-name> -- /bin/bash

# Run single command
kubectl exec <pod-name> -- mysql -u root -p<password> bankappdb
```

### Port Forwarding

```bash
# Forward service port
kubectl port-forward svc/mysql-service 3306:3306

# Forward pod port
kubectl port-forward pod/<pod-name> 8080:8080
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Pod Pending State

```bash
# Check events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Solution: May need more nodes or resource requests too high
```

#### 2. Image Pull Errors

```bash
# Check image availability
docker pull <image-name>

# View image pull events
kubectl describe pod <pod-name> | grep -A 5 Events

# Solution: Ensure image exists in registry and credentials are correct
```

#### 3. Database Connection Issues

```bash
# Verify MySQL pod is running
kubectl get pods -l app=mysql

# Check MySQL logs
kubectl logs deployment/mysql

# Test connection
kubectl exec -it <bankapp-pod> -- \
  mysql -h mysql-service -u root -p<password> -e "SELECT 1;"
```

#### 4. Persistent Volume Issues

```bash
# Check PVCs
kubectl get pvc

# Check PV status
kubectl get pv

# Describe PVC for events
kubectl describe pvc mysql-pvc
```

#### 5. Terraform State Issues

```bash
# View state
terraform show

# Validate state
terraform validate

# Refresh state
terraform refresh

# Backup state before any operations
cp terraform.tfstate terraform.tfstate.backup
```

### Debug Commands

```bash
# Get cluster information
kubectl cluster-info dump

# Check all resources
kubectl get all -A

# Describe cluster nodes
kubectl describe nodes

# View events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource quota usage
kubectl describe quota
```

---

## 📈 Performance Tuning

### Kubernetes Optimization

```bash
# Enable horizontal pod autoscaling
kubectl apply -f Boardgame/k8s/base/10-hpa.yaml

# Set resource limits
kubectl set resources deployment bankapp \
  --limits=cpu=1,memory=512Mi \
  --requests=cpu=250m,memory=256Mi

# Use pod disruption budgets
kubectl apply -f Boardgame/k8s/base/11-pdb.yaml
```

### Database Optimization

```bash
# Monitor MySQL performance
kubectl exec -it <mysql-pod> -- \
  mysql -u root -p<password> -e "SHOW PROCESSLIST;"

# Check slow queries
kubectl logs deployment/mysql | grep "Query_time"
```

---

## 🔄 CI/CD Integration

### Jenkins Pipeline

```bash
# View Jenkins jobs
cat Boardgame/Jenkinsfile

# Trigger build
./scripts/Jenkins/run.sh
```

### Automated Deployments

```bash
# Build and push image
mvn clean package -f Boardgame/pom.xml
docker build -t adijaiswal/bankapp:latest Boardgame/
docker push adijaiswal/bankapp:latest

# Deploy via pipeline
kubectl apply -f Manifest/manifest.yaml
```

---

## 📚 Documentation

For more detailed information, refer to:

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [RBAC Documentation](.rbac.md)

---

## 📝 Contributing

1. Create a feature branch
2. Make changes
3. Test locally
4. Submit pull request

---

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

---

## ✉️ Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Last Updated**: April 2026
**Maintained By**: DevOps Team
```
