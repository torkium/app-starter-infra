#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILES="${COMPOSE_FILES:- -f docker-compose.yml -f docker-compose.dev.yml}"
BACK_HEALTH_URL="${BACK_HEALTH_URL:-https://localhost${BACK_HEALTH_PATH:-/api/health}}"
FRONT_HEALTH_URL="${FRONT_HEALTH_URL:-https://localhost/}"
API_DOC_URL="${API_DOC_URL:-https://localhost/api/doc.json}"
MERCURE_HEALTH_URL="${MERCURE_HEALTH_URL:-https://localhost/.well-known/mercure}"

cd "$ROOT_DIR"

compose() {
  docker compose ${COMPOSE_FILES} "$@"
}

assert_running_service() {
  local service="$1"
  local running_services

  running_services="$(compose ps --services --status running)"
  if ! grep -qx "$service" <<<"$running_services"; then
    echo "Service not running: $service" >&2
    exit 1
  fi
}

assert_env_value() {
  local service="$1"
  local key="$2"
  local expected="${3:-__non_empty__}"
  local value

  value="$(compose exec -T "$service" sh -lc "printenv $key" 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "Missing runtime variable $key in service $service" >&2
    exit 1
  fi

  if [ "$expected" != "__non_empty__" ] && [ "$value" != "$expected" ]; then
    echo "Unexpected runtime variable $key in service $service: expected '$expected', got '$value'" >&2
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts="${3:-20}"
  local sleep_seconds="${4:-5}"

  for _ in $(seq 1 "$attempts"); do
    if curl -kfsS "$url" >/dev/null; then
      return 0
    fi
    sleep "$sleep_seconds"
  done

  echo "HTTP check failed for $label: $url" >&2
  exit 1
}

wait_for_mercure() {
  local url="$1"
  local attempts="${2:-20}"
  local sleep_seconds="${3:-5}"
  local status

  for _ in $(seq 1 "$attempts"); do
    status="$(curl -ksS -o /dev/null -w '%{http_code}' "$url" || true)"
    if [ "$status" = "200" ] || [ "$status" = "400" ]; then
      return 0
    fi
    sleep "$sleep_seconds"
  done

  echo "HTTP check failed for mercure endpoint: $url" >&2
  exit 1
}

wait_for_http "$BACK_HEALTH_URL" "backend health"
wait_for_http "$FRONT_HEALTH_URL" "frontend root"
wait_for_http "$API_DOC_URL" "api doc"
wait_for_mercure "$MERCURE_HEALTH_URL"

assert_running_service db
assert_running_service redis
assert_running_service mercure
assert_running_service back
assert_running_service front
assert_running_service nginx
assert_running_service worker_default
assert_running_service worker_mail
assert_running_service worker_outbox
assert_running_service scheduler

compose exec -T db sh -lc 'mysqladmin ping -h 127.0.0.1 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"' >/dev/null
compose exec -T redis redis-cli ping | grep -qx "PONG"

assert_env_value back APP_ENV
assert_env_value back APP_SECRET
assert_env_value back DATABASE_URL
assert_env_value back MERCURE_JWT_SECRET
assert_env_value front NEXT_PUBLIC_APP_URL
assert_env_value front API_BASE_URL
assert_env_value front NEXT_PUBLIC_MERCURE_DISABLED

compose exec -T back sh -lc 'php bin/console about --env="${APP_ENV}"' >/dev/null
compose exec -T scheduler sh -lc 'ps -o args= 1 | grep -F "${SCHEDULER_COMMAND:-/usr/local/bin/scheduler-loop.sh}"' >/dev/null

echo "Stack runtime checks passed"
