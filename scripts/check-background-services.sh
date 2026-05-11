#!/usr/bin/env bash
set -euo pipefail

required_services=(worker_default worker_mail worker_outbox scheduler)
running_services="$(docker compose ${COMPOSE_FILES:- -f docker-compose.yml} ps --services --status running)"

for service in "${required_services[@]}"; do
  if ! grep -qx "$service" <<<"$running_services"; then
    echo "Required background service is not running: $service" >&2
    exit 1
  fi
done

echo "Background services are running"
