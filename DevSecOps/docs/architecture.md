# Architecture

## Platform layers

- CI/CD: Jenkins and GitHub Actions
- Quality gate: SonarQube
- Artifact repository: Nexus
- Security: Trivy and OPA
- Observability: Prometheus and Grafana
- GitOps: Argo CD application manifests
- IaC: Terraform multi-cloud live stack

## One-click flow

1. `deploy-oneclick.sh` starts the local platform with Docker Compose.
2. `scripts/bootstrap.sh` performs health checks.
3. CI pipelines validate scripts, compose config, Terraform, and Trivy scans.
4. GitOps manifests deploy a demo app into Kubernetes when Argo CD is pointed at a real repo.
