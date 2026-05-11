#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 /absolute/path/to/backup.sql.gz" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Backup file not found: $INPUT_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"
gzip -dc "$INPUT_FILE" | docker compose ${COMPOSE_FILES:- -f docker-compose.yml -f docker-compose.dev.yml} \
  exec -T db sh -lc 'exec mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

echo "Restore completed from $INPUT_FILE"

MEDIA_ARCHIVE="${INPUT_FILE%.sql.gz}-media.tar.gz"
compose_project_name="${COMPOSE_PROJECT_NAME:-}"
if [ -z "$compose_project_name" ] && [ -f "$ROOT_DIR/.env" ]; then
  compose_project_name="$(awk -F= '$1 == "COMPOSE_PROJECT_NAME" { print substr($0, index($0, "=") + 1) }' "$ROOT_DIR/.env" | tail -n 1)"
fi

media_volume="${compose_project_name:-starter}_media_uploads"
if [ -f "$MEDIA_ARCHIVE" ] && docker volume inspect "$media_volume" >/dev/null 2>&1; then
  docker run --rm \
    -v "${media_volume}:/target" \
    -v "$(dirname "$MEDIA_ARCHIVE"):/backup:ro" \
    alpine:3.22 \
    sh -lc "rm -rf /target/* && mkdir -p /target && tar -xzf \"/backup/$(basename "$MEDIA_ARCHIVE")\" -C /target"
  echo "Media restore completed from $MEDIA_ARCHIVE"
fi
