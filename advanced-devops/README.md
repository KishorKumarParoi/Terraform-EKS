# Advanced DevOps One-Click Platform

This project is a very advanced DevOps starter that bundles CI/CD, DevSecOps, GitOps, monitoring, and multi-cloud Terraform in a single deployable workspace.

## Included Toolchain

- CI/CD: GitHub Actions, Jenkins
- DevSecOps: Trivy, SonarQube, OPA policy checks
- Artifact repository: Nexus
- GitOps: Argo CD manifests
- Observability: Prometheus and Grafana
- Multi-cloud IaC: Terraform for AWS, Azure, and GCP

## One-click deployment

```bash
cd advanced-devops
chmod +x deploy-oneclick.sh scripts/*.sh gitops/argocd/install.sh
./deploy-oneclick.sh
```

## Platform URLs

- Jenkins: `http://localhost:8080`
- SonarQube: `http://localhost:9000`
- Nexus: `http://localhost:8081`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

## CI/CD and Security

- GitHub workflow template: `ci/github/workflows/platform-pipeline.yml`
- Jenkins pipeline template: `jenkins/Jenkinsfile`
- Trivy config: `security/trivy/trivy.yaml`
- OPA image policy: `security/policies/opa/deny-unscanned-images.rego`

## GitOps and Multi-cloud

- Argo CD install and app bootstrap: `gitops/argocd/install.sh`
- Demo app manifests: `gitops/apps/demo-app`
- Terraform live stack: `terraform/live/dev`

## Quick validation

```bash
make validate
```

## Notes

- This starter is production-oriented scaffolding and is safe to customize for your internal standards.
- Replace placeholder repo URL in GitOps application before enabling automated sync.
- Configure cloud credentials before running Terraform.
