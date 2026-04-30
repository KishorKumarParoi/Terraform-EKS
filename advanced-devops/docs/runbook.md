# Runbook

## Start Platform

```bash
./deploy-oneclick.sh
```

## Validate Configuration

```bash
make validate
```

## Stop Platform

```bash
make down
```

## Common Recovery

1. Restart all services: `make restart`
2. Check service logs: `make logs`
3. Re-run bootstrap checks: `./scripts/bootstrap.sh`
4. Validate compose config: `docker compose config`
