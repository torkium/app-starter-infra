#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/init-project.sh --project-name <name> --github-owner <owner> [options]

Options:
  --project-name <name>   Project slug, for example: my-app
  --github-owner <name>   GitHub owner, for example: my-org
  --back-repo <name>      Backend repository name, default: <project>-back
  --front-repo <name>     Frontend repository name, default: <project>-front
  --infra-repo <name>     Infra repository name, default: <project>-infra
  --registry <value>      Container registry prefix, default: ghcr.io/<owner>
  --help                  Show this help
EOF
}

require_value() {
  local option="$1"
  local value="${2:-}"

  if [ -z "$value" ]; then
    echo "Missing value for $option" >&2
    exit 1
  fi
}

title_case() {
  printf '%s' "$1" | tr '_-' '  ' | awk '{
    for (i = 1; i <= NF; i++) {
      $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2));
    }
    print;
  }'
}

pascal_case() {
  title_case "$1" | tr -d ' '
}

replace_literal() {
  local file="$1"
  local old="$2"
  local new="$3"

  OLD_VALUE="$old" NEW_VALUE="$new" perl -0pi -e 's/\Q$ENV{OLD_VALUE}\E/$ENV{NEW_VALUE}/g' "$file"
}

assert_file() {
  local file="$1"

  if [ ! -f "${ROOT_DIR}/${file}" ]; then
    echo "Expected file not found: ${ROOT_DIR}/${file}" >&2
    exit 1
  fi
}

PROJECT_NAME=""
GITHUB_OWNER=""
BACK_REPO=""
FRONT_REPO=""
INFRA_REPO=""
REGISTRY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-name)
      require_value "$1" "${2:-}"
      PROJECT_NAME="$2"
      shift 2
      ;;
    --github-owner)
      require_value "$1" "${2:-}"
      GITHUB_OWNER="$2"
      shift 2
      ;;
    --back-repo)
      require_value "$1" "${2:-}"
      BACK_REPO="$2"
      shift 2
      ;;
    --front-repo)
      require_value "$1" "${2:-}"
      FRONT_REPO="$2"
      shift 2
      ;;
    --infra-repo)
      require_value "$1" "${2:-}"
      INFRA_REPO="$2"
      shift 2
      ;;
    --registry)
      require_value "$1" "${2:-}"
      REGISTRY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$PROJECT_NAME" ] || [ -z "$GITHUB_OWNER" ]; then
  usage >&2
  exit 1
fi

BACK_REPO="${BACK_REPO:-${PROJECT_NAME}-back}"
FRONT_REPO="${FRONT_REPO:-${PROJECT_NAME}-front}"
INFRA_REPO="${INFRA_REPO:-${PROJECT_NAME}-infra}"
REGISTRY="${REGISTRY:-ghcr.io/${GITHUB_OWNER}}"

PROJECT_TITLE="$(title_case "$PROJECT_NAME")"
PROJECT_PASCAL="$(pascal_case "$PROJECT_NAME")"
PROJECT_DB_IDENTIFIER="${PROJECT_NAME//-/_}"
APP_DOMAIN="${PROJECT_NAME}.localhost"

FILES=(
  "AGENTS.md"
  "README.md"
  ".env.example"
  "env/.env.dev.example"
  ".github/workflows/ci.yml"
  "docker-compose.yml"
  "docker-compose.dev.yml"
  "bootstrap/github/environment.env.example"
  "scripts/init.sh"
  "scripts/render-compose-env.sh"
  "scripts/render-runtime-env.sh"
  "scripts/release-state-dir.sh"
  "docs/github-variables-secrets.md"
  "docs/quick-start.md"
  "docs/deployment.md"
  "docs/server-installation.md"
  "docs/operations.md"
  "docs/cloudflare-worker.md"
  "docs/backup-pra.md"
  "docs/runbooks-ops.md"
  "monitoring/grafana/provisioning/dashboards/dashboards.yml"
  "monitoring/grafana/dashboards/overview.json"
  "monitoring/grafana/dashboards/logs.json"
  "monitoring/prometheus/alerts/containers.yml"
  "edge-media-worker/wrangler.toml.example"
)

for file in "${FILES[@]}"; do
  assert_file "$file"
done

for file in "${FILES[@]}"; do
  target="${ROOT_DIR}/${file}"
  replace_literal "$target" "../app-starter-back" "../${BACK_REPO}"
  replace_literal "$target" "../app-starter-front" "../${FRONT_REPO}"
  replace_literal "$target" "/run/starter-secrets/jwt" "/run/${PROJECT_NAME}-secrets/jwt"
  replace_literal "$target" "ghcr.io/example/starter-back" "${REGISTRY}/${BACK_REPO}"
  replace_literal "$target" "ghcr.io/example/starter-front" "${REGISTRY}/${FRONT_REPO}"
  replace_literal "$target" "app-starter-back" "$BACK_REPO"
  replace_literal "$target" "app-starter-front" "$FRONT_REPO"
  replace_literal "$target" "owner/starter_back" "${GITHUB_OWNER}/${BACK_REPO}"
  replace_literal "$target" "owner/starter_front" "${GITHUB_OWNER}/${FRONT_REPO}"
  replace_literal "$target" "owner/starter_infra" "${GITHUB_OWNER}/${INFRA_REPO}"
  replace_literal "$target" "starter-back" "$BACK_REPO"
  replace_literal "$target" "starter-front" "$FRONT_REPO"
  replace_literal "$target" "starter-infra" "$INFRA_REPO"
  replace_literal "$target" "starter_back" "$BACK_REPO"
  replace_literal "$target" "starter_front" "$FRONT_REPO"
  replace_literal "$target" "starter_infra" "$INFRA_REPO"
  replace_literal "$target" "Starter infra" "${PROJECT_TITLE} infra"
  replace_literal "$target" "starter-private-media" "${PROJECT_NAME}-private-media"
  replace_literal "$target" "starter-backups" "${PROJECT_NAME}-backups"
  replace_literal "$target" "starter-media-edge" "${PROJECT_NAME}-media-edge"
  replace_literal "$target" "starter-overview" "${PROJECT_NAME}-overview"
  replace_literal "$target" "starter-logs" "${PROJECT_NAME}-logs"
  replace_literal "$target" "starter-observability" "${PROJECT_NAME}-observability"
  replace_literal "$target" "AppObservability" "${PROJECT_PASCAL}Observability"
  replace_literal "$target" "StarterObservability" "${PROJECT_PASCAL}Observability"
  replace_literal "$target" ".starter_infra" ".${INFRA_REPO}"
  replace_literal "$target" "/srv/starter/releases" "/srv/${PROJECT_NAME}/releases"
done

replace_literal "${ROOT_DIR}/.env.example" "COMPOSE_PROJECT_NAME=starter" "COMPOSE_PROJECT_NAME=${PROJECT_NAME}"
replace_literal "${ROOT_DIR}/.env.example" "MYSQL_DATABASE=app" "MYSQL_DATABASE=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/.env.example" "MYSQL_USER=app" "MYSQL_USER=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/.env.example" "APP_DOMAIN=app.local" "APP_DOMAIN=${APP_DOMAIN}"
replace_literal "${ROOT_DIR}/.env.example" "https://app.local" "https://${APP_DOMAIN}"
replace_literal "${ROOT_DIR}/.env.example" "APP_DOMAIN=app.localhost" "APP_DOMAIN=${APP_DOMAIN}"
replace_literal "${ROOT_DIR}/.env.example" "https://app.localhost" "https://${APP_DOMAIN}"

replace_literal "${ROOT_DIR}/env/.env.dev.example" "MYSQL_DATABASE=app" "MYSQL_DATABASE=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/env/.env.dev.example" "MYSQL_USER=app" "MYSQL_USER=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/env/.env.dev.example" "DATABASE_URL=mysql://app:dev-password@db:3306/app" "DATABASE_URL=mysql://${PROJECT_DB_IDENTIFIER}:dev-password@db:3306/${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/env/.env.dev.example" "https://app.local" "https://${APP_DOMAIN}"
replace_literal "${ROOT_DIR}/env/.env.dev.example" "https://app.localhost" "https://${APP_DOMAIN}"

replace_literal "${ROOT_DIR}/bootstrap/github/environment.env.example" "ENV_VAR__COMPOSE_PROJECT_NAME=starter" "ENV_VAR__COMPOSE_PROJECT_NAME=${PROJECT_NAME}"
replace_literal "${ROOT_DIR}/bootstrap/github/environment.env.example" "ENV_VAR__MYSQL_DATABASE=app" "ENV_VAR__MYSQL_DATABASE=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/bootstrap/github/environment.env.example" "ENV_VAR__MYSQL_USER=app" "ENV_VAR__MYSQL_USER=${PROJECT_DB_IDENTIFIER}"
replace_literal "${ROOT_DIR}/monitoring/grafana/provisioning/dashboards/dashboards.yml" "folder: Starter" "folder: ${PROJECT_TITLE}"
replace_literal "${ROOT_DIR}/monitoring/grafana/provisioning/dashboards/dashboards.yml" "folder: App" "folder: ${PROJECT_TITLE}"
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/overview.json" '"starter"' "\"${PROJECT_NAME}\""
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/overview.json" '"title": "App Overview"' "\"title\": \"${PROJECT_TITLE} Overview\""
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/overview.json" '"title": "Starter Overview"' "\"title\": \"${PROJECT_TITLE} Overview\""
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/logs.json" '"starter"' "\"${PROJECT_NAME}\""
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/logs.json" '"title": "App Logs"' "\"title\": \"${PROJECT_TITLE} Logs\""
replace_literal "${ROOT_DIR}/monitoring/grafana/dashboards/logs.json" '"title": "Starter Logs"' "\"title\": \"${PROJECT_TITLE} Logs\""

cat <<EOF
Project templating applied in starter_infra.

Applied values:
- project: ${PROJECT_NAME}
- owner: ${GITHUB_OWNER}
- registry: ${REGISTRY}
- back repo: ${BACK_REPO}
- front repo: ${FRONT_REPO}
- infra repo: ${INFRA_REPO}
EOF
