#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_FILE="${1:-$BACKUP_DIR/mysql-${TIMESTAMP}.sql.gz}"

mkdir -p "$BACKUP_DIR"

cd "$ROOT_DIR"
docker compose ${COMPOSE_FILES:- -f docker-compose.yml -f docker-compose.dev.yml} \
  exec -T db sh -lc 'exec mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
  | gzip > "$OUTPUT_FILE"

echo "Backup written to $OUTPUT_FILE"

compose_project_name="${COMPOSE_PROJECT_NAME:-}"
if [ -z "$compose_project_name" ] && [ -f "$ROOT_DIR/.env" ]; then
  compose_project_name="$(awk -F= '$1 == "COMPOSE_PROJECT_NAME" { print substr($0, index($0, "=") + 1) }' "$ROOT_DIR/.env" | tail -n 1)"
fi

media_volume="${compose_project_name:-starter}_media_uploads"
if docker volume inspect "$media_volume" >/dev/null 2>&1; then
  media_archive="${OUTPUT_FILE%.sql.gz}-media.tar.gz"
  docker run --rm \
    -v "${media_volume}:/source:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:3.22 \
    sh -lc "cd /source && tar -czf \"/backup/$(basename "$media_archive")\" ."
  echo "Media backup written to $media_archive"
fi
