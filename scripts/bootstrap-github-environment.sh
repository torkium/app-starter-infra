#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
ENVIRONMENTS=""
ENV_FILE=""
MASK_OUTPUT="false"
ONLY_KEYS=""
REPO="${GITHUB_REPOSITORY:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_TEMPLATE="$ROOT_DIR/bootstrap/github/environment.env.example"

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-github-environment.sh --envs=dev,staging --env-file=bootstrap/github/environment.dev.env [--repo=owner/repo] [--apply] [--mask] [--only=KEY1,KEY2]

The env file must define values using these prefixes:
  ENV_VAR__KEY=value
  ENV_SECRET__KEY=value

Defaults:
  --apply : false, prints intended changes
  --mask  : hide secret values in dry-run output
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) MODE="apply" ;;
    --envs=*) ENVIRONMENTS="${1#*=}" ;;
    --env-file=*) ENV_FILE="${1#*=}" ;;
    --repo=*) REPO="${1#*=}" ;;
    --mask) MASK_OUTPUT="true" ;;
    --only=*) ONLY_KEYS="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ -z "$ENVIRONMENTS" ] || [ -z "$ENV_FILE" ] || [ -z "$REPO" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$EXPECTED_TEMPLATE" ]; then
  echo "Missing schema template: $EXPECTED_TEMPLATE" >&2
  exit 1
fi

gh auth status >/dev/null 2>&1 || {
  echo "gh CLI must be authenticated" >&2
  exit 1
}

declare -A ALLOWED_KEYS=()
if [ -n "$ONLY_KEYS" ]; then
  IFS=',' read -r -a only_items <<< "$ONLY_KEYS"
  for item in "${only_items[@]}"; do
    key="$(printf '%s' "$item" | xargs)"
    [ -n "$key" ] && ALLOWED_KEYS["$key"]=1
  done
fi

should_process() {
  local key="$1"
  if [ -z "$ONLY_KEYS" ]; then
    return 0
  fi
  [ -n "${ALLOWED_KEYS[$key]:-}" ]
}

validate_env_file_schema() {
  local env_file="$1"
  local template_file="$2"
  local missing=0
  declare -A provided=()

  while IFS='=' read -r raw_key _; do
    [ -z "$raw_key" ] && continue
    case "$raw_key" in
      \#*) continue ;;
      ENV_VAR__*|ENV_SECRET__*)
        provided["$raw_key"]=1
        ;;
    esac
  done < "$env_file"

  while IFS='=' read -r raw_key _; do
    [ -z "$raw_key" ] && continue
    case "$raw_key" in
      \#*) continue ;;
      ENV_VAR__*)
        key="${raw_key#ENV_VAR__}"
        if should_process "$key" && [ -z "${provided[$raw_key]:-}" ]; then
          echo "Missing expected key in env file: $raw_key" >&2
          missing=1
        fi
        ;;
      ENV_SECRET__*)
        key="${raw_key#ENV_SECRET__}"
        if should_process "$key" && [ -z "${provided[$raw_key]:-}" ]; then
          echo "Missing expected key in env file: $raw_key" >&2
          missing=1
        fi
        ;;
    esac
  done < "$template_file"

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

mask_value() {
  local value="$1"
  if [ "$MASK_OUTPUT" != "true" ]; then
    printf '%s' "$value"
    return 0
  fi

  local len="${#value}"
  if [ "$len" -le 8 ]; then
    printf '[masked]'
  else
    printf '%s...%s' "${value:0:4}" "${value: -4}"
  fi
}

apply_var() {
  local env_name="$1"
  local key="$2"
  local value="$3"
  if ! should_process "$key"; then
    return 0
  fi
  if [ "$MODE" = "apply" ]; then
    gh variable set "$key" --repo "$REPO" --env "$env_name" --body "$value"
    echo "SET var: $env_name $key"
  else
    echo "DRY-RUN var: $env_name $key=$(mask_value "$value")"
  fi
}

apply_secret() {
  local env_name="$1"
  local key="$2"
  local value="$3"
  if ! should_process "$key"; then
    return 0
  fi
  if [ "$MODE" = "apply" ]; then
    gh secret set "$key" --repo "$REPO" --env "$env_name" --body "$value"
    echo "SET secret: $env_name $key"
  else
    echo "DRY-RUN secret: $env_name $key=$(mask_value "$value")"
  fi
}

validate_env_file_schema "$ENV_FILE" "$EXPECTED_TEMPLATE"

IFS=',' read -r -a ENV_LIST <<< "$ENVIRONMENTS"

for env_name in "${ENV_LIST[@]}"; do
  env_name="$(printf '%s' "$env_name" | xargs)"
  [ -z "$env_name" ] && continue

  while IFS='=' read -r raw_key raw_value; do
    [ -z "$raw_key" ] && continue
    case "$raw_key" in
      \#*) continue ;;
      ENV_VAR__*)
        key="${raw_key#ENV_VAR__}"
        apply_var "$env_name" "$key" "$raw_value"
        ;;
      ENV_SECRET__*)
        key="${raw_key#ENV_SECRET__}"
        apply_secret "$env_name" "$key" "$raw_value"
        ;;
    esac
  done < "$ENV_FILE"
done
