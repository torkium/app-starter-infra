#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v restic >/dev/null 2>&1; then
  echo "restic is required for offsite backups" >&2
  exit 1
fi

if [ -f .env ]; then
  # shellcheck disable=SC1091
  . ./.env
fi

DEPLOY_ENV="${DEPLOY_ENV:-dev}"
RUNTIME_ENV_FILE="env/.env.${DEPLOY_ENV}"
if [ ! -f "$RUNTIME_ENV_FILE" ]; then
  echo "Missing runtime env file: $RUNTIME_ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$RUNTIME_ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
LATEST_BACKUP="${1:-}"

if [ -z "$LATEST_BACKUP" ]; then
  LATEST_BACKUP="$(ls -1t "$BACKUP_DIR"/mysql-*.sql.gz 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo "No local backup file found. Run ./scripts/backup.sh first or pass a file path." >&2
  exit 1
fi

export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"

if [ -z "$RESTIC_REPOSITORY" ] || [ -z "$RESTIC_PASSWORD" ]; then
  echo "RESTIC_REPOSITORY and RESTIC_PASSWORD are required" >&2
  exit 1
fi

if [ -n "${B2_KEY_ID:-}" ] && [ -n "${B2_APP_KEY:-}" ]; then
  export B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-$B2_KEY_ID}"
  export B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-$B2_APP_KEY}"
fi

if ! restic snapshots >/dev/null 2>&1; then
  restic init
fi

restic backup "$LATEST_BACKUP"

MEDIA_ARCHIVE="${LATEST_BACKUP%.sql.gz}-media.tar.gz"
if [ -f "$MEDIA_ARCHIVE" ]; then
  restic backup "$MEDIA_ARCHIVE"
fi

restic forget \
  --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
  --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
  --keep-monthly "${RESTIC_KEEP_MONTHLY:-2}" \
  --prune

echo "Offsite backup completed for $LATEST_BACKUP"
