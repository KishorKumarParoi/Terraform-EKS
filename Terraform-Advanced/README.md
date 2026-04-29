# Multi-Cloud Terraform Advanced Platform

This folder is now structured as a CV-ready multi-cloud Terraform platform. The target design is intentionally broader than a single-cluster AWS deployment so it can demonstrate architecture, module design, environment separation, and operational thinking.

## Target Cloud Strategy

- **AWS** is the primary platform.
- **Azure** is the secondary enterprise or DR platform.
- Shared Terraform modules keep the project consistent across clouds.
- CI/CD, policy checks, and observability live alongside the infrastructure code.

## What This Project Demonstrates

- Multi-cloud provider design
- Reusable Terraform modules
- Environment overlays for dev, staging, and prod
- Security and policy guardrails
- Kubernetes platform delivery on EKS and AKS
- Monitoring, logging, and operational readiness
- Pipeline-friendly structure for GitHub Actions or Jenkins

## Repository Layout

```text
Terraform-Advanced/
├── clouds/
│   ├── aws/
│   └── azure/
├── modules/
│   ├── compute/
│   ├── network/
│   ├── observability/
│   └── security/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── pipelines/
├── policies/
├── scripts/
└── docs/
```

## How To Use

1. Start from the cloud entrypoint you want under `clouds/`.
2. Extend the relevant module under `modules/`.
3. Add environment-specific values under `environments/`.
4. Run validation from `scripts/validate.sh`.
5. Add CI/CD and promotion rules through `pipelines/`.

## Suggested Resume Line

> Built a multi-cloud Terraform platform with AWS and Azure entrypoints, reusable modules, validation tooling, policy checks, and production-style documentation.

## Notes

The older AWS-only implementation that already exists in this folder is still useful as a reference, but the new structure above is the target layout for the advanced multicloud version.

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
