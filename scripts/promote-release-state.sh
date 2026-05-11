#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$("$ROOT_DIR/scripts/release-state-dir.sh" "${DEPLOY_ENV:-dev}")"

mkdir -p "$STATE_DIR"

if [ -f "$STATE_DIR/current.env" ]; then
  cp "$STATE_DIR/current.env" "$STATE_DIR/previous.env"
fi

cp "$ROOT_DIR/.env" "$STATE_DIR/current.env"

if [ -n "${PRE_MIGRATION_BACKUP_FILE:-}" ] && [ -f "${PRE_MIGRATION_BACKUP_FILE}" ]; then
  cp "${PRE_MIGRATION_BACKUP_FILE}" "$STATE_DIR/previous-db.sql.gz"

  media_snapshot="${PRE_MIGRATION_BACKUP_FILE%.sql.gz}-media.tar.gz"
  if [ -f "$media_snapshot" ]; then
    cp "$media_snapshot" "$STATE_DIR/previous-media.tar.gz"
  fi
fi

echo "Release state promoted"
