# SLO and Cost Targets

## Reliability SLOs

- CI pipeline success rate: >= 99.0%
- Deployment lead time (commit to deploy): <= 30 minutes
- MTTR for failed deploys: <= 15 minutes
- Monitoring stack availability: >= 99.5%

## Security SLOs

- Critical vulnerability backlog age: < 72 hours
- 100% container images scanned before production deploy
- 100% IaC changes pass static validation and policy checks

## Cost Guardrails

- Local platform footprint should fit a single workstation with 16 GB RAM.
- Cloud dev environment monthly target: <= $150
- Use autoscaling and burstable compute classes for non-prod workloads.
- Run nightly budget checks and alert on >= 80% spend threshold.
