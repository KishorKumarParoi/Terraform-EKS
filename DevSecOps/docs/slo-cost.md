# SLO and Cost Targets

## Reliability SLOs

- Platform services available: 99.5% in local or dev environments
- Pipeline validation success rate: 99%
- Security scans required before merge: 100%
- Mean time to recover from a bad deploy: under 15 minutes

## Cost guardrails

- Local deployment should fit on a single workstation.
- Dev cloud footprint target: under $100/month.
- Prefer burstable compute and autoscaling for non-prod workloads.
- Remove idle environments after use.
