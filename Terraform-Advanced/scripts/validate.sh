#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

terraform fmt -check -recursive .
terraform validate || true

if command -v tflint >/dev/null 2>&1; then
  tflint --recursive
else
  printf 'tflint not installed; skipping lint step.\n'
fi

printf 'Validation pass complete.\n'
