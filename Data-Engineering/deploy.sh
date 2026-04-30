#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Starting Data Engineering stack..."
docker compose up -d --build

echo "Stack is up. Useful URLs:"
echo "  API:       http://localhost:8000"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
