# Data-Engineering

A one-click deploy starter kit for a full ETL stack.

## What it includes

- ETL job that reads `data/raw/sales.csv`, loads PostgreSQL, and builds summaries
- FastAPI serving layer with health and summary endpoints
- Prometheus metrics from the API
- Grafana with Prometheus datasource and a starter dashboard
- PostgreSQL for raw and curated data
- One-click launcher via `deploy.sh`

## Architecture

`CSV source -> ETL worker -> PostgreSQL -> FastAPI serving -> Prometheus -> Grafana`

## One-click deploy

1. Optionally copy the environment template if you want to override defaults:

```bash
cp .env.example .env
```

2. Start everything:

```bash
chmod +x deploy.sh
./deploy.sh
```

## Useful URLs

- API: http://localhost:8000
- Health: http://localhost:8000/health
- Summary: http://localhost:8000/summary
- Metrics: http://localhost:8000/metrics
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

## Cost and reliability SLOs

Starter targets:
- Dev stack budget: under $50/month for a small cloud VM or local Docker host
- ETL success rate: 99.5% of scheduled runs
- API availability: 99.9% in a managed deployment
- Mean time to recover: under 15 minutes for a failed ETL run
- Freshness goal: latest summary data within 15 minutes of raw file arrival

## Local validation

```bash
docker compose config
python -m compileall app
```

## Next upgrade path

- Replace the CSV source with object storage or Kafka
- Swap the single ETL worker for Airflow or Dagster orchestration
- Add cloud-backed storage and remote state
- Export dashboards and alerts to your cloud monitoring stack
