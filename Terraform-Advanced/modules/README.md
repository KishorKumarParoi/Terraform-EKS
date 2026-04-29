# Modules

The modules folder is split by cloud and responsibility:

- `modules/network/` for routing and network topology
- `modules/compute/` for Kubernetes platform layers
- `modules/security/` for IAM, RBAC, and guardrails
- `modules/observability/` for monitoring and logging patterns

Each module should stay small, reusable, and cloud-specific when needed.
