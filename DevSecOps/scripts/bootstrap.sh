#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

curl -fsS http://localhost:${SONARQUBE_PORT:-9000}/api/system/status >/dev/null
curl -fsS http://localhost:${PROMETHEUS_PORT:-9090}/-/ready >/dev/null
curl -fsS http://localhost:${GRAFANA_PORT:-3000}/api/health >/dev/null

echo "Bootstrap health checks passed."
