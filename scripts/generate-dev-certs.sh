#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-app.localhost}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT_DIR/certs/dev"
PRIVATE_KEY_FILE="$CERT_DIR/privkey.pem"
FULLCHAIN_FILE="$CERT_DIR/fullchain.pem"

mkdir -p "$CERT_DIR"

if [ "${FORCE_DEV_CERTS_REGENERATION:-0}" != "1" ] && [ -f "$PRIVATE_KEY_FILE" ] && [ -f "$FULLCHAIN_FILE" ]; then
  echo "Keep existing development certificates in $CERT_DIR"
  exit 0
fi

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$PRIVATE_KEY_FILE" \
  -out "$FULLCHAIN_FILE" \
  -days 365 \
  -subj "/CN=$DOMAIN"

echo "Certificates generated in $CERT_DIR"
