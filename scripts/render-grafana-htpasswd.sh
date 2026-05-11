#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_FILE="${1:-$ROOT_DIR/env/grafana.htpasswd}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -n "${GRAFANA_HTPASSWD:-}" ]; then
  printf '%s\n' "${GRAFANA_HTPASSWD}" > "$OUTPUT_FILE"
  chmod 600 "$OUTPUT_FILE"
  echo "Grafana htpasswd written to $OUTPUT_FILE from provided content"
  exit 0
fi

: "${GRAFANA_BASIC_AUTH_USER:=starter}"

if [ -z "${GRAFANA_BASIC_AUTH_PASSWORD:-}" ]; then
  GRAFANA_BASIC_AUTH_PASSWORD="$(openssl rand -base64 24 | tr -d '\n' | tr '/+' 'ab')"
  export GRAFANA_BASIC_AUTH_PASSWORD
  echo "Generated a random Grafana basic auth password for this environment"
fi

hash="$(openssl passwd -apr1 "${GRAFANA_BASIC_AUTH_PASSWORD}")"
printf '%s:%s\n' "${GRAFANA_BASIC_AUTH_USER}" "${hash}" > "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE"

echo "Grafana htpasswd generated in $OUTPUT_FILE"
