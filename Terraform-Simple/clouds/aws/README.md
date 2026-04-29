AWS base infrastructure for Terraform-Simple.

This folder contains the AWS-specific Terraform configuration (VPC, subnets, IGW, route tables, security group).

Usage:

1. Change into this directory:
   ```bash
   cd Terraform-Simple/clouds/aws
   ```
2. Initialize and run Terraform:
   ```bash
   terraform init
   terraform plan -var-file="../../terraform.tfvars"
   terraform apply -var-file="../../terraform.tfvars"
   ```

Note: Keep sensitive values out of the repo and use a remote backend for state when collaborating.
