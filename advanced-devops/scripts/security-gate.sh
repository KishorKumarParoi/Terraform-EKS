#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-alpine:3.20}"
SEVERITY="${SEVERITY:-CRITICAL,HIGH}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "Trivy CLI not found. Install it or run the scan in CI."
  exit 1
fi

trivy image --exit-code 1 --severity "$SEVERITY" "$IMAGE"
