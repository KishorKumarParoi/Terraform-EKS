.PHONY: help init validate plan apply destroy fmt lint docs show state check

# Variables
TERRAFORM_DIR := $(shell pwd)
REGION ?= us-east-1
CLUSTER_NAME ?= kkp-cluster

help: ## Display this help message
	@echo "EKS Terraform - Available Commands"
	@echo "===================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check: ## Check prerequisites
	@echo "Checking Terraform..."
	@terraform -version
	@echo "\nChecking AWS CLI..."
	@aws --version
	@echo "\nChecking kubectl..."
	@kubectl version --client
	@echo "\nChecking AWS credentials..."
	@aws sts get-caller-identity

init: ## Initialize Terraform working directory
	@echo "Initializing Terraform..."
	@terraform init
	@echo "✓ Initialization complete"

validate: init ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	@terraform validate
	@echo "✓ Configuration is valid"

fmt: ## Format Terraform code
	@echo "Formatting Terraform code..."
	@terraform fmt -recursive
	@echo "✓ Code formatted"

plan: init validate ## Generate and show execution plan
	@echo "Generating Terraform plan..."
	@terraform plan -out=tfplan
	@echo "✓ Plan saved to tfplan"
	@echo "\nTo review the plan:"
	@echo "  terraform show tfplan"

plan-destroy: init validate ## Show plan for destruction
	@echo "Generating destruction plan..."
	@terraform plan -destroy -out=destroy_plan
	@echo "✓ Destroy plan saved"

apply: init plan ## Apply Terraform configuration
	@echo "Applying Terraform plan..."
	@terraform apply tfplan
	@echo "✓ Infrastructure deployed successfully"
	@echo "\nConfiguring kubectl..."
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	@echo "✓ kubectl configured"
	@echo "\nVerifying cluster..."
	@kubectl cluster-info
	@kubectl get nodes

apply-force: init validate ## Apply without plan (dangerous!)
	@echo "WARNING: Applying without plan review!"
	@terraform apply -auto-approve
	@echo "✓ Infrastructure deployed"

refresh: ## Refresh Terraform state
	@echo "Refreshing Terraform state..."
	@terraform refresh
	@echo "✓ State refreshed"

destroy: init ## Destroy all resources (with confirmation)
	@echo "WARNING: This will destroy all infrastructure!"
	@terraform destroy

destroy-force: init ## Destroy without confirmation (dangerous!)
	@echo "DANGER: Force destroying all resources!"
	@terraform destroy -auto-approve

show: ## Show current Terraform state
	@echo "Terraform State:"
	@terraform show

state-list: ## List all resources in state
	@echo "Resources in Terraform state:"
	@terraform state list

output: ## Display Terraform outputs
	@echo "Terraform Outputs:"
	@terraform output

output-json: ## Display outputs as JSON
	@terraform output -json

import: ## Import existing AWS resource (usage: make import RESOURCE=aws_eks_cluster.kkp ID=kkp-cluster)
	@if [ -z "$(RESOURCE)" ] || [ -z "$(ID)" ]; then \
		echo "Usage: make import RESOURCE=<resource> ID=<id>"; \
		echo "Example: make import RESOURCE=aws_eks_cluster.kkp ID=kkp-cluster"; \
	else \
		terraform import $(RESOURCE) $(ID); \
	fi

lock: ## Lock Terraform state (for team collaboration)
	@terraform state lock -force

unlock: ## Unlock Terraform state
	@terraform state unlock

clean: ## Clean Terraform cache
	@echo "Cleaning Terraform cache..."
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl tfplan
	@echo "✓ Cache cleaned"

docs: ## Generate Terraform documentation
	@echo "Generating documentation..."
	@echo "## Terraform Configuration" > TERRAFORM_VARS.md
	@echo "" >> TERRAFORM_VARS.md
	@echo "### Variables" >> TERRAFORM_VARS.md
	@echo "" >> TERRAFORM_VARS.md
	@grep -A 5 "variable" variable.tf | grep -E '(variable|description|type|default)' >> TERRAFORM_VARS.md || true
	@echo "✓ Documentation generated in TERRAFORM_VARS.md"

lint: ## Lint Terraform code (requires tflint)
	@if command -v tflint &> /dev/null; then \
		echo "Linting Terraform code..."; \
		tflint .; \
		echo "✓ Linting complete"; \
	else \
		echo "tflint not installed. Install from: https://github.com/terraform-linters/tflint"; \
	fi

security-check: ## Security check (requires checkov)
	@if command -v checkov &> /dev/null; then \
		echo "Running security checks..."; \
		checkov -d . --framework terraform; \
	else \
		echo "checkov not installed. Install from: https://www.checkov.io/"; \
	fi

cost-estimate: ## Estimate infrastructure costs (requires infracost)
	@if command -v infracost &> /dev/null; then \
		echo "Estimating costs..."; \
		infracost breakdown --path . --format table; \
	else \
		echo "infracost not installed. Install from: https://www.infracost.io/"; \
	fi

graph: ## Generate resource dependency graph
	@echo "Generating resource dependency graph..."
	@terraform graph | dot -Tpng > graph.png
	@echo "✓ Graph saved to graph.png"

version: ## Show Terraform and provider versions
	@terraform version

upgrade: ## Upgrade Terraform providers
	@echo "Upgrading providers..."
	@terraform init -upgrade
	@echo "✓ Providers upgraded"

status: ## Show cluster status
	@echo "Cluster Status:"
	@aws eks describe-cluster \
		--name $(CLUSTER_NAME) \
		--region $(REGION) \
		--query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}' \
		--output table

nodes: ## List cluster nodes
	@echo "Cluster Nodes:"
	@kubectl get nodes -o wide

pods: ## List all pods
	@echo "All Pods:"
	@kubectl get pods -A

logs: ## Show cluster logs
	@aws logs tail "/aws/eks/$(CLUSTER_NAME)/cluster" --follow

backend-init: ## Initialize S3 backend for remote state
	@echo "Create S3 bucket and DynamoDB table first, then uncomment backend in versions.tf"
	@echo "Example S3 bucket name: my-terraform-state-$$(date +%s)"

cost-estimate: ## Show estimated monthly cost for current configuration
	@echo "📊 Cost Estimation:"
	@echo "   EKS Cluster: ~$73/month"
	@echo "   EC2 (2x t3.medium): ~$68/month"
	@echo "   Load Balancers (2x): ~$37/month"
	@echo "   Storage & Networking: ~$8/month"
	@echo "   ─────────────────────"
	@echo "   TOTAL: ~$185/month"
	@echo ""
	@echo "💡 Optimization potential: 35-75% savings"
	@echo "   See COST_OPTIMIZATION.md for details"

apply-dev: init ## Deploy with DEV cost-optimized configuration (~$40-50/month)
	@echo "⚠️  Deploying DEVELOPMENT configuration (cost-optimized)"
	@echo "   - Spot instances enabled (can be interrupted)"
	@echo "   - Single node (1x t3.small)"
	@echo "   - Minimal logging"
	@terraform apply -var-file=terraform.tfvars.dev

apply-staging: init ## Deploy with STAGING cost-balanced configuration (~$80-100/month)
	@echo "⚠️  Deploying STAGING configuration (cost-balanced)"
	@echo "   - Spot instances enabled"
	@echo "   - 2x t3.small nodes with auto-scaling to 4"
	@echo "   - Minimal logging"
	@terraform apply -var-file=terraform.tfvars.staging

apply-prod: init ## Deploy with PRODUCTION configuration (~$150-180/month)
	@echo "✓ Deploying PRODUCTION configuration (reliable)"
	@echo "   - On-demand instances (no interruptions)"
	@echo "   - 3x t3.medium nodes with auto-scaling to 6"
	@echo "   - Full logging enabled"
	@terraform apply -var-file=terraform.tfvars.prod

plan-dev: init ## Plan DEV cost-optimized configuration
	@terraform plan -var-file=terraform.tfvars.dev -out=dev.tfplan

plan-staging: init ## Plan STAGING cost-balanced configuration
	@terraform plan -var-file=terraform.tfvars.staging -out=staging.tfplan

plan-prod: init ## Plan PRODUCTION configuration
	@terraform plan -var-file=terraform.tfvars.prod -out=prod.tfplan

apply-spot: init ## Apply with Spot instances enabled (60-70% EC2 savings)
	@echo "💰 Enabling Spot instances..."
	@terraform apply -var='enable_spot_instances=true'

apply-small-instances: init ## Apply with smaller instance types (50% EC2 savings)
	@echo "💰 Using smaller instance types (t3.small)..."
	@terraform apply -var='use_smaller_instance_types=true' -var='node_instance_types=["t3.small"]'

apply-optimized: init ## Apply with all cost optimizations enabled
	@echo "💰 Applying all cost optimizations..."
	@echo "   - Spot instances"
	@echo "   - Smaller instance types"
	@echo "   - Minimal logging"
	@terraform apply \
		-var='enable_cost_optimization=true' \
		-var='enable_spot_instances=true' \
		-var='use_smaller_instance_types=true' \
		-var='cluster_log_types=["api"]'

cost-optimization-guide: ## Show cost optimization guide
	@echo "📄 Opening Cost Optimization Guide..."
	@test -f COST_OPTIMIZATION.md && cat COST_OPTIMIZATION.md || echo "COST_OPTIMIZATION.md not found"

all: init validate fmt plan apply ## Run init, validate, fmt, plan, and apply

.DEFAULT_GOAL := help
