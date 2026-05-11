#!/usr/bin/env bash
set -euo pipefail

BACK_HEALTH_URL="${BACK_HEALTH_URL:-https://localhost${BACK_HEALTH_PATH:-/api/health}}"
FRONT_HEALTH_URL="${FRONT_HEALTH_URL:-https://localhost/}"
ATTEMPTS="${HEALTHCHECK_ATTEMPTS:-12}"
SLEEP_SECONDS="${HEALTHCHECK_SLEEP_SECONDS:-5}"

for _ in $(seq 1 "$ATTEMPTS"); do
  if curl -kfsS "$BACK_HEALTH_URL" >/dev/null && curl -kfsS "$FRONT_HEALTH_URL" >/dev/null; then
    echo "Health check succeeded"
    exit 0
  fi

  sleep "$SLEEP_SECONDS"
done

echo "Health check failed" >&2
exit 1
