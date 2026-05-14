#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$("$ROOT_DIR/scripts/release-state-dir.sh" "${DEPLOY_ENV:-dev}")"
TARGET="${1:-both}"
VERSION="${2:-}"
COMPOSE_ARGS=${COMPOSE_FILES:- -f docker-compose.yml}

cd "$ROOT_DIR"

read_env_value() {
  local file="$1"
  local key="$2"
  awk -F= -v target="$key" '$1 == target { print substr($0, index($0, "=") + 1) }' "$file" | tail -n 1
}

persist_rollback_state() {
  local previous_env_source="$1"
  local current_env_source="$2"
  local previous_db_source="${3:-}"
  local previous_media_source="${4:-}"

  mkdir -p "$STATE_DIR"
  cp "$current_env_source" "$STATE_DIR/current.env"
  cp "$previous_env_source" "$STATE_DIR/previous.env"
  if [ -f "$runtime_env_file" ]; then
    cp "$runtime_env_file" "$STATE_DIR/current-runtime.env"
  fi
  if [ -f "$before_rollback_runtime_env" ]; then
    cp "$before_rollback_runtime_env" "$STATE_DIR/previous-runtime.env"
  fi

  if [ -n "$previous_db_source" ] && [ -f "$previous_db_source" ]; then
    cp "$previous_db_source" "$STATE_DIR/previous-db.sql.gz"
  fi

  if [ -n "$previous_media_source" ] && [ -f "$previous_media_source" ]; then
    cp "$previous_media_source" "$STATE_DIR/previous-media.tar.gz"
  elif [ -f "$STATE_DIR/previous-media.tar.gz" ]; then
    rm -f "$STATE_DIR/previous-media.tar.gz"
  fi
}

if [ ! -f "$STATE_DIR/current.env" ]; then
  echo "No current deployment snapshot found in $STATE_DIR/current.env" >&2
  exit 1
fi

runtime_env_file="$ROOT_DIR/env/.env.${DEPLOY_ENV:-dev}"
before_rollback_env="$STATE_DIR/rollback-current.env"
before_rollback_runtime_env="$STATE_DIR/rollback-current-runtime.env"
before_rollback_db="$STATE_DIR/rollback-current-db.sql.gz"
before_rollback_media="${before_rollback_db%.sql.gz}-media.tar.gz"
rollback_restore_started=0
persisted_rollback_state=0

cp "$STATE_DIR/current.env" "$before_rollback_env"
if [ -f "$STATE_DIR/current-runtime.env" ]; then
  cp "$STATE_DIR/current-runtime.env" "$before_rollback_runtime_env"
fi

stop_application_stack() {
  docker compose ${COMPOSE_ARGS} stop back front nginx worker_default worker_mail worker_outbox scheduler >/dev/null 2>&1 || true
}

recover_current_application() {
  cp "$before_rollback_env" .env
  if [ -f "$before_rollback_runtime_env" ]; then
    cp "$before_rollback_runtime_env" "$runtime_env_file"
  fi
  if [ "$rollback_restore_started" = "1" ] && [ -f "$before_rollback_db" ]; then
    docker compose ${COMPOSE_ARGS} up -d db redis mercure >/dev/null
    COMPOSE_FILES="${COMPOSE_ARGS}" "$ROOT_DIR/scripts/restore.sh" "$before_rollback_db" >/dev/null
  fi
  docker compose ${COMPOSE_ARGS} up -d --remove-orphans back front nginx >/dev/null
  docker compose ${COMPOSE_ARGS} up -d worker_default worker_mail worker_outbox scheduler >/dev/null
}

restore_previous_runtime_state() {
  local db_backup_file="$STATE_DIR/previous-db.sql.gz"

  if [ ! -f "$db_backup_file" ]; then
    echo "No previous database snapshot found in $db_backup_file" >&2
    exit 1
  fi

  docker compose ${COMPOSE_ARGS} up -d db redis mercure >/dev/null
  COMPOSE_FILES="${COMPOSE_ARGS}" "$ROOT_DIR/scripts/restore.sh" "$db_backup_file"
}

case "$TARGET" in
  back|both)
    if [ -n "$VERSION" ]; then
      echo "Image-only backend rollbacks with an explicit version are disabled by default because they do not restore the database schema." >&2
      echo "Restore the matching database snapshot first, or unset VERSION and rollback to the persisted previous release." >&2
      exit 1
    fi

    if [ ! -f "$STATE_DIR/previous.env" ]; then
      echo "No previous deployment snapshot found in $STATE_DIR/previous.env" >&2
      exit 1
    fi
    if [ ! -f "$STATE_DIR/previous-runtime.env" ]; then
      echo "No previous runtime env snapshot found in $STATE_DIR/previous-runtime.env" >&2
      exit 1
    fi

    stop_application_stack
    trap 'recover_current_application' ERR
    COMPOSE_FILES="${COMPOSE_ARGS}" "$ROOT_DIR/scripts/backup.sh" "$before_rollback_db"
    cp "$STATE_DIR/previous.env" .env
    cp "$STATE_DIR/previous-runtime.env" "$runtime_env_file"

    rollback_restore_started=1
    restore_previous_runtime_state

    if [ "$TARGET" = "back" ]; then
      docker compose ${COMPOSE_ARGS} pull back
      docker compose ${COMPOSE_ARGS} up -d back
    else
      docker compose ${COMPOSE_ARGS} pull back front
      docker compose ${COMPOSE_ARGS} up -d back front nginx
    fi
    docker compose ${COMPOSE_ARGS} up -d worker_default worker_mail worker_outbox scheduler

    ;;
  front)
    cp "$before_rollback_env" .env
    if [ -f "$before_rollback_runtime_env" ]; then
      cp "$before_rollback_runtime_env" "$runtime_env_file"
    fi

    if [ -n "$VERSION" ]; then
      sed -i "s|^FRONT_IMAGE_TAG=.*|FRONT_IMAGE_TAG=$VERSION|" .env
    else
      if [ ! -f "$STATE_DIR/previous.env" ]; then
        echo "No previous deployment snapshot found in $STATE_DIR/previous.env" >&2
        exit 1
      fi

      previous_front_tag="$(read_env_value "$STATE_DIR/previous.env" FRONT_IMAGE_TAG)"
      if [ -z "$previous_front_tag" ]; then
        echo "Unable to resolve FRONT_IMAGE_TAG from $STATE_DIR/previous.env" >&2
        exit 1
      fi

      sed -i "s|^FRONT_IMAGE_TAG=.*|FRONT_IMAGE_TAG=$previous_front_tag|" .env
    fi

    docker compose ${COMPOSE_ARGS} pull front
    docker compose ${COMPOSE_ARGS} up -d front

    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    exit 1
    ;;
esac

if [ "$TARGET" = "back" ] || [ "$TARGET" = "both" ]; then
  "$ROOT_DIR/scripts/check-background-services.sh"
fi

BACK_HEALTH_PATH="${BACK_HEALTH_PATH:-/api/ready}" "$ROOT_DIR/scripts/healthcheck.sh"

case "$TARGET" in
  back|both)
    persist_rollback_state \
      "$before_rollback_env" \
      "$ROOT_DIR/.env" \
      "$before_rollback_db" \
      "$before_rollback_media"
    persisted_rollback_state=1
    trap - ERR
    ;;
  front)
    persist_rollback_state "$before_rollback_env" "$ROOT_DIR/.env"
    persisted_rollback_state=1
    ;;
esac

echo "Rollback completed"
