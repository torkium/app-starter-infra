#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-app.local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT_DIR/certs/dev"
PRIVATE_KEY_FILE="$CERT_DIR/privkey.pem"
FULLCHAIN_FILE="$CERT_DIR/fullchain.pem"

mkdir -p "$CERT_DIR"

certificate_matches_domain() {
  local subject alt_names

  subject="$(openssl x509 -in "$FULLCHAIN_FILE" -noout -subject -nameopt RFC2253 2>/dev/null || true)"
  alt_names="$(openssl x509 -in "$FULLCHAIN_FILE" -noout -ext subjectAltName 2>/dev/null || true)"

  [[ "$subject" == *"CN=${DOMAIN}"* ]] && [[ "$alt_names" == *"DNS:${DOMAIN}"* ]]
}

if [ "${FORCE_DEV_CERTS_REGENERATION:-0}" != "1" ] && [ -f "$PRIVATE_KEY_FILE" ] && [ -f "$FULLCHAIN_FILE" ] && certificate_matches_domain; then
  echo "Keep existing development certificates in $CERT_DIR"
  exit 0
fi

OPENSSL_CONFIG_FILE="$(mktemp)"
trap 'rm -f "$OPENSSL_CONFIG_FILE"' EXIT

cat > "$OPENSSL_CONFIG_FILE" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = ${DOMAIN}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOF

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$PRIVATE_KEY_FILE" \
  -out "$FULLCHAIN_FILE" \
  -days 365 \
  -config "$OPENSSL_CONFIG_FILE" \
  -extensions v3_req

echo "Certificates generated in $CERT_DIR"
