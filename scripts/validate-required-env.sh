#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-compose}"

require_keys() {
  local missing=0
  local key
  for key in "$@"; do
    if [ -z "${!key:-}" ]; then
      echo "Missing required variable: ${key}" >&2
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

require_all_or_none() {
  local first="$1"
  local second="$2"

  if { [ -n "${!first:-}" ] && [ -z "${!second:-}" ]; } || { [ -z "${!first:-}" ] && [ -n "${!second:-}" ]; }; then
    echo "Variables ${first} and ${second} must be provided together" >&2
    exit 1
  fi
}

require_url() {
  local key="$1"
  local value="${!key:-}"

  if [ -z "$value" ]; then
    echo "Missing required URL variable: ${key}" >&2
    exit 1
  fi

  case "$value" in
    http://*|https://*) ;;
    *)
      echo "Variable ${key} must be an absolute URL, got: ${value}" >&2
      exit 1
      ;;
  esac
}

require_boolean() {
  local key="$1"
  local value="${!key:-}"

  case "$value" in
    true|false) ;;
    *)
      echo "Variable ${key} must be 'true' or 'false', got: ${value}" >&2
      exit 1
      ;;
  esac
}

require_min_length() {
  local key="$1"
  local minimum="$2"
  local value="${!key:-}"

  if [ "${#value}" -lt "$minimum" ]; then
    echo "Variable ${key} must be at least ${minimum} characters long" >&2
    exit 1
  fi
}

require_not_weak_secret() {
  local key="$1"
  local normalized
  normalized="$(printf '%s' "${!key:-}" | tr '[:upper:]' '[:lower:]')"

  case "$normalized" in
    ""|change-me*|changeme*|default*|secret|password|admin|starter-observe|starter-observe-*|dev-observe-password|dev-observe-secret)
      echo "Variable ${key} uses a weak or default value" >&2
      exit 1
      ;;
  esac
}

case "$MODE" in
  compose)
    require_keys APP_DOMAIN BACK_IMAGE FRONT_IMAGE
    ;;
  runtime)
    require_keys APP_DOMAIN APP_SECRET MYSQL_PASSWORD MYSQL_ROOT_PASSWORD MERCURE_JWT_SECRET NEXT_PUBLIC_APP_URL NEXT_PUBLIC_MEDIA_UPLOAD_BASE_URL NEXT_PUBLIC_MERCURE_DISABLED
    require_all_or_none STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET
    require_all_or_none JWT_PRIVATE_KEY_PEM JWT_PUBLIC_KEY_PEM
    require_url NEXT_PUBLIC_APP_URL
    require_url NEXT_PUBLIC_MEDIA_UPLOAD_BASE_URL
    require_boolean NEXT_PUBLIC_MERCURE_DISABLED
    if [ "${NEXT_PUBLIC_MERCURE_DISABLED}" = "false" ]; then
      require_url NEXT_PUBLIC_MERCURE_URL
    fi
    if [ -n "${NEXT_PUBLIC_MEDIA_BASE_URL:-}" ]; then
      require_url NEXT_PUBLIC_MEDIA_BASE_URL
    fi
    ;;
  observability)
    require_keys GRAFANA_ADMIN_PASSWORD GRAFANA_SECRET_KEY
    require_min_length GRAFANA_ADMIN_PASSWORD 16
    require_min_length GRAFANA_SECRET_KEY 24
    require_not_weak_secret GRAFANA_ADMIN_PASSWORD
    require_not_weak_secret GRAFANA_SECRET_KEY
    ;;
  media-edge)
    require_keys MEDIA_EDGE_BASE_URL B2_ENDPOINT B2_BUCKET
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
