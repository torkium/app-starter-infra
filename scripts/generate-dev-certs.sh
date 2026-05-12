#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-app.local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT_DIR/certs/dev"
PRIVATE_KEY_FILE="$CERT_DIR/privkey.pem"
FULLCHAIN_FILE="$CERT_DIR/fullchain.pem"
MKCERT_BIN="$(command -v mkcert || true)"
CERTUTIL_BIN="$(command -v certutil || true)"

if [ -z "$MKCERT_BIN" ] && [ -x "${HOME}/.local/bin/mkcert" ]; then
  MKCERT_BIN="${HOME}/.local/bin/mkcert"
fi

if [ -z "$CERTUTIL_BIN" ] && [ -x "${HOME}/.local/bin/certutil" ]; then
  CERTUTIL_BIN="${HOME}/.local/bin/certutil"
fi

mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/rootCA-key.pem" ]; then
  echo "Refusing to continue: never copy mkcert rootCA-key.pem into ${CERT_DIR}" >&2
  exit 1
fi

certificate_matches_domain() {
  local alt_names

  alt_names="$(openssl x509 -in "$FULLCHAIN_FILE" -noout -ext subjectAltName 2>/dev/null || true)"

  [[ "$alt_names" == *"DNS:${DOMAIN}"* ]]
}

trust_mkcert_ca_in_user_nss_db() {
  if [ -z "$CERTUTIL_BIN" ]; then
    return 1
  fi

  local ca_root nss_db
  ca_root="$("$MKCERT_BIN" -CAROOT)"
  nss_db="${HOME}/.pki/nssdb"

  mkdir -p "$nss_db"
  if [ ! -f "$nss_db/cert9.db" ]; then
    "$CERTUTIL_BIN" -N --empty-password -d "sql:${nss_db}"
  fi

  "$CERTUTIL_BIN" -D -d "sql:${nss_db}" -n "mkcert development CA" 2>/dev/null || true
  "$CERTUTIL_BIN" -A -d "sql:${nss_db}" -t "C,," -n "mkcert development CA" -i "${ca_root}/rootCA.pem"
}

if [ "${FORCE_DEV_CERTS_REGENERATION:-0}" != "1" ] && [ -f "$PRIVATE_KEY_FILE" ] && [ -f "$FULLCHAIN_FILE" ] && certificate_matches_domain; then
  echo "Keep existing development certificates in $CERT_DIR"
  exit 0
fi

if [ -n "$MKCERT_BIN" ]; then
  if ! "$MKCERT_BIN" -install; then
    cat >&2 <<EOF
mkcert could not install its local CA in every trust store. Certificate
generation will continue, but browsers will trust it only if the mkcert CA is
already trusted in their store.
EOF
    if trust_mkcert_ca_in_user_nss_db; then
      echo "mkcert local CA installed in the user NSS database."
    fi
  fi
  "$MKCERT_BIN" \
    -key-file "$PRIVATE_KEY_FILE" \
    -cert-file "$FULLCHAIN_FILE" \
    "$DOMAIN" localhost 127.0.0.1 ::1
  echo "Trusted development certificates generated with mkcert in $CERT_DIR"
  exit 0
fi

cat >&2 <<EOF
mkcert is not installed; falling back to a self-signed OpenSSL certificate.
Browsers can load the page after a manual exception, but service workers require
a trusted certificate. Install mkcert, then rerun:

  FORCE_DEV_CERTS_REGENERATION=1 make certs APP_DOMAIN=${DOMAIN}
  make front-dev
EOF

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
