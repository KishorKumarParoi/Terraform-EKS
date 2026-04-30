# DevSecOps Starter Kit

A one-click deployable DevSecOps platform with CI/CD, code quality, supply-chain security, monitoring, GitOps, and policy enforcement.

## Included services

- Jenkins for pipeline orchestration
- SonarQube for code quality and quality gates
- Nexus Repository for artifacts
- Trivy for image and filesystem scanning
- OPA for policy-as-code guardrails
- Prometheus + Grafana for observability
- GitHub Actions and Jenkins pipeline templates
- Argo CD GitOps manifests for cluster deployment
- Secure app delivery workflow (scan -> build -> sign -> GitOps deploy)
- GitOps promotion workflow for `dev -> staging -> prod`

## One-click deploy

```bash
cd devsecops
chmod +x deploy-oneclick.sh
./deploy-oneclick.sh
```

## Quick validation

```bash
make validate
kubectl kustomize gitops/apps/demo-app/overlays/dev >/dev/null
kubectl kustomize gitops/apps/demo-app/overlays/staging >/dev/null
kubectl kustomize gitops/apps/demo-app/overlays/prod >/dev/null
```

## Secure delivery flow

1. Merge changes to `sample-app/` on `main`.
2. Workflow `ci/github/workflows/app-delivery.yml` runs:
	- Trivy filesystem scan
	- Build and push image to GHCR
	- Trivy image scan
	- Cosign keyless signing
	- Update `gitops/apps/demo-app/overlays/dev/kustomization.yaml` with new image/tag
3. Argo CD syncs dev automatically.

## Promotion flow

- Manual workflow: `ci/github/workflows/promote.yml`
- Local command option:

```bash
chmod +x scripts/promote.sh
./scripts/promote.sh dev staging
./scripts/promote.sh staging prod
```

## URLs

- Jenkins: http://localhost:8080
- SonarQube: http://localhost:9000
- Nexus: http://localhost:8081
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- OPA: http://localhost:8181

## Suggested next step

Connect your app repo to the pipelines and point Argo CD at a real GitOps repository URL.

## Branch protection mapping

Use `docs/branch-protection-policy.md` to configure required checks and approvals for `main`, `staging`, and `prod`.
