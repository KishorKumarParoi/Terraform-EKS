#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but not installed."
  exit 1
fi

if ! command -v docker compose >/dev/null 2>&1; then
  echo "Docker Compose plugin is required (docker compose)."
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
fi

make bootstrap

echo ""
echo "Advanced DevOps platform is up."
echo "Jenkins:    http://localhost:${JENKINS_PORT:-8080}"
echo "SonarQube:  http://localhost:${SONARQUBE_PORT:-9000}"
echo "Nexus:      http://localhost:${NEXUS_PORT:-8081}"
echo "Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
echo "Grafana:    http://localhost:${GRAFANA_PORT:-3000}"
