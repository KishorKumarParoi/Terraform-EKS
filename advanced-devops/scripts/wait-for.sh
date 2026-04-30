#!/usr/bin/env bash
set -euo pipefail

URL="$1"
NAME="$2"
MAX_RETRIES="${3:-60}"
SLEEP_SEC="${4:-3}"

for ((i=1; i<=MAX_RETRIES; i++)); do
  if curl -fsS "$URL" >/dev/null 2>&1; then
    echo "$NAME is ready"
    exit 0
  fi
  echo "Waiting for $NAME ($i/$MAX_RETRIES)..."
  sleep "$SLEEP_SEC"
done

echo "Timed out waiting for $NAME"
exit 1
