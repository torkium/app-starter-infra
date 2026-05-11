#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
RUNTIME_FILE="${ROOT_DIR}/env/.env.dev"
BOOTSTRAP_FILE="${ROOT_DIR}/bootstrap/github/dev.env"
APP_DOMAIN="${1:-app.local}"

mkdir -p "${ROOT_DIR}/env" "${ROOT_DIR}/bootstrap/github"

copy_if_missing() {
  local source="$1"
  local target="$2"

  if [ -f "$target" ]; then
    echo "Keep existing $target"
    return 0
  fi

  cp "$source" "$target"
  echo "Created $target"
}

copy_if_missing "${ROOT_DIR}/.env.example" "$ENV_FILE"
copy_if_missing "${ROOT_DIR}/env/.env.dev.example" "$RUNTIME_FILE"
copy_if_missing "${ROOT_DIR}/bootstrap/github/environment.env.example" "$BOOTSTRAP_FILE"

"${ROOT_DIR}/scripts/generate-dev-certs.sh" "$APP_DOMAIN"
"${ROOT_DIR}/scripts/render-grafana-htpasswd.sh"

cat <<EOF
Starter infra initialized.

Files prepared:
- ${ENV_FILE}
- ${RUNTIME_FILE}
- ${BOOTSTRAP_FILE}

Next steps:
1. Review .env and env/.env.dev
2. If not already done, run make init in your sibling backend and frontend repositories
3. Read docs/quick-start.md for Stripe, B2 and GitHub Environment setup
4. Run: make up
5. Validate: make health
EOF
