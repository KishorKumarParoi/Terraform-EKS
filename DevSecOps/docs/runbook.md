# Runbook

## Start the platform

```bash
cd devsecops
./deploy-oneclick.sh
```

## Validate configuration

```bash
make validate
kubectl kustomize gitops/apps/demo-app/overlays/dev >/dev/null
kubectl kustomize gitops/apps/demo-app/overlays/staging >/dev/null
kubectl kustomize gitops/apps/demo-app/overlays/prod >/dev/null
```

## Stop the platform

```bash
make down
```

## Common checks

- Jenkins: `http://localhost:8080`
- SonarQube: `http://localhost:9000`
- Nexus: `http://localhost:8081`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- OPA: `http://localhost:8181`

## Promote releases

```bash
chmod +x scripts/promote.sh
./scripts/promote.sh dev staging
./scripts/promote.sh staging prod
```
