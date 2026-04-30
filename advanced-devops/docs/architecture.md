# Architecture

## Core Stack

- CI/CD: GitHub Actions pipeline template and Jenkins pipeline
- Artifact and package: Nexus Repository
- Code quality: SonarQube
- Security: Trivy scanning and OPA policy guardrails
- Observability: Prometheus + Grafana
- GitOps: Argo CD application manifests
- IaC: Terraform multi-cloud baseline (AWS, Azure, GCP)

## Deployment Pattern

1. One-click launcher provisions local platform services with Docker Compose.
2. CI pipeline validates Terraform, security scans, and manifest rendering.
3. GitOps sync deploys workloads into Kubernetes.
4. Multi-cloud Terraform handles shared cloud primitives for storage and platform foundations.
