#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/wait-for.sh "http://localhost:${PROMETHEUS_PORT:-9090}/-/ready" "Prometheus"
./scripts/wait-for.sh "http://localhost:${GRAFANA_PORT:-3000}/api/health" "Grafana"
./scripts/wait-for.sh "http://localhost:${SONARQUBE_PORT:-9000}/api/system/status" "SonarQube"

echo "Bootstrap checks complete. Platform dependencies are healthy."
