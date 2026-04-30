# Branch Protection and Required Checks Policy

This document maps release policy to branches and CI checks.

## Branch model

- `main`: source of truth for application code and dev GitOps updates.
- `staging`: optional integration branch used for pre-prod verification.
- `prod`: protected release branch for production-grade promotion workflows.

## Required branch protection settings

### `main`

- Require pull request before merging.
- Require at least 1 approval.
- Dismiss stale approvals on new commits.
- Require status checks to pass:
  - `validate` (from `ci/github/workflows/platform.yml`)
  - `scan-build-sign` (from `ci/github/workflows/app-delivery.yml`)
- Restrict direct pushes.

### `staging`

- Require pull request before merging.
- Require at least 1 approval.
- Require status checks to pass:
  - `promote-staging` (from `ci/github/workflows/promote.yml`)
- Restrict direct pushes.

### `prod`

- Require pull request before merging.
- Require at least 2 approvals.
- Require code owner review.
- Require status checks to pass:
  - `promote-prod` (from `ci/github/workflows/promote.yml`)
- Restrict direct pushes.
- Enable signed commits/tags if available.

## Environment protection mapping

Configure GitHub Environments with required reviewers:

- `dev`: no manual approval (auto deploy allowed).
- `staging`: at least 1 approver.
- `prod`: at least 2 approvers.

These environment names are already referenced by workflows:

- `deploy-dev-gitops` job -> `dev`
- `promote-staging` job -> `staging`
- `promote-prod` job -> `prod`

## Allowed promotion paths

Only these transitions are allowed:

- `dev -> staging`
- `staging -> prod`

This is enforced in `ci/github/workflows/promote.yml` by the `validate-transition` job.
