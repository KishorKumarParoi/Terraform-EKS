# Environments

Use this folder to keep environment-specific values and promotion rules.

Recommended pattern:

- `dev/` for experimental or low-cost builds
- `staging/` for pre-production validation
- `prod/` for controlled production delivery

Keep the cloud entrypoints under `clouds/` and layer environment values here so the project stays easy to reason about.
