# Terraform-Simple Configuration

A simplified, customizable Terraform configuration for AWS infrastructure deployment with VPC, Subnets, Internet Gateway, and security components.

## Directory Structure

```
Terraform-Simple/
├── locals.tf                    # Local values and centralized configuration
├── variables.tf                 # Variable definitions with validation
├── main.tf                      # Main Terraform configuration
├── output.tf                    # Output values
├── terraform.tfvars             # Variable values (default/development)
├── terraform.tfvars.example     # Example template for variable values
└── README.md                    # This file
```

## Key Features

### Customizable Configuration
- **locals.tf**: Centralized local values that can be easily modified
- **variables.tf**: All configurable parameters with validation rules
- **terraform.tfvars**: Easy-to-update values file

### Infrastructure Components
- **VPC**: Virtual Private Cloud with customizable CIDR block
- **Subnets**: Multiple subnets across different availability zones
- **Internet Gateway**: For public internet connectivity
- **Route Table**: With routes to the internet gateway
- **Security Group**: For network access control
- **Network ACL**: Additional layer of network security

### Best Practices
- Input validation on all variables
- Consistent resource naming convention
- Common tags applied to all resources
- Environment-based configuration
- Proper dependency management
- Version constraints on Terraform and providers

## Getting Started

### 1. Configure Variables

Copy the example template:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values:
```hcl
aws_region     = "us-east-1"
project_name   = "my-project"
environment    = "dev"  # or "staging", "prod"
vpc_cidr_block = "10.0.0.0/16"
subnet_count   = 2
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

## Variable Customization

### AWS Configuration
```hcl
aws_region = "us-east-1"  # Change AWS region
```

### Project Details
```hcl
project_name = "kkp"              # Used for resource naming
environment  = "dev"              # dev, staging, or prod
```

### VPC and Network
```hcl
vpc_cidr_block     = "10.0.0.0/16"
subnet_count       = 2
availability_zones = ["us-east-1a", "us-east-1b"]
```

### Optional SSH Access
```hcl
ssh_key_name = "your-key-pair-name"  # Leave empty if not needed
```

### Additional Tags
```hcl
additional_tags = {
  Owner      = "DevOps-Team"
  Contact    = "devops@example.com"
  CostCenter = "Engineering"
}
```

## Outputs

After successful deployment, Terraform will output:
- `vpc_id`: ID of the created VPC
- `subnet_ids`: List of subnet IDs
- `internet_gateway_id`: Internet Gateway ID
- `security_group_id`: Security group ID
- `project_name`: Project name used
- `environment`: Deployment environment

Access outputs after apply:
```bash
terraform output vpc_id
terraform output subnet_ids
terraform output -json  # All outputs as JSON
```

## Environment-Based Deployment

Deploy to different environments using variable files:

```bash
# Development
terraform apply -var-file="terraform.tfvars"

# Staging
terraform apply -var-file="terraform.tfvars.staging"

# Production
terraform apply -var-file="terraform.tfvars.prod"
```

Create `terraform.tfvars.staging` and `terraform.tfvars.prod` with respective values.

## Customization Examples

### Change VPC CIDR Block
Edit `terraform.tfvars`:
```hcl
vpc_cidr_block = "172.16.0.0/16"
```

### Add More Subnets
```hcl
subnet_count       = 3
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
```

### Update Project Naming
```hcl
project_name = "myapp"
environment  = "prod"
```

All resource names will automatically reflect these changes through the `locals.tf` configuration.

## Maintenance and Updates

### View Current State
```bash
terraform show
```

### View Resource List
```bash
terraform state list
```

### Refresh State
```bash
terraform refresh
```

### Plan Destruction (View what will be deleted)
```bash
terraform plan -destroy
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Troubleshooting

### Variable Validation Errors
If you get validation errors, check:
- Project name contains only lowercase letters, numbers, and hyphens
- Environment is one of: dev, staging, prod
- VPC CIDR is in valid CIDR notation
- Subnet count is between 1 and 4

### AWS Credentials
Ensure AWS credentials are configured:
```bash
aws configure
# or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

### AWS Region Access
Verify you have access to resources in the selected region and that availability zones are valid for that region.

## Security Considerations

- Keep `terraform.tfstate` and `terraform.tfvars` secure
- Don't commit sensitive values to version control
- Use `.gitignore` to exclude state files:
  ```
  *.tfstate
  *.tfstate.backup
  .terraform/
  terraform.tfvars
  ```
- Consider using Terraform Cloud for remote state
- Use IAM roles with minimal required permissions

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Terraform Configuration Language](https://www.terraform.io/docs/language)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)

---

**Last Updated**: 2026-04-23
