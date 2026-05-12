#!/usr/bin/env sh
set -eu

mode="${1:-safe}"
until_filter="${DOCKER_CLEANUP_UNTIL:-}"

case "$mode" in
  dev)
    until_filter="${until_filter:-24h}"
    ;;
  safe|deploy|prod|staging)
    until_filter="${until_filter:-168h}"
    ;;
  hard)
    until_filter="${until_filter:-24h}"
    ;;
  *)
    echo "Usage: $0 [dev|safe|deploy|staging|prod|hard]" >&2
    exit 2
    ;;
esac

echo "Docker cleanup mode: ${mode}, keeping unused resources newer than ${until_filter}"

docker container prune -f --filter "until=${until_filter}"
docker network prune -f --filter "until=${until_filter}"

case "$mode" in
  dev|hard)
    docker image prune -af --filter "until=${until_filter}"
    docker builder prune -af --filter "until=${until_filter}"
    ;;
  safe|deploy|prod|staging)
    docker image prune -f --filter "until=${until_filter}"
    docker builder prune -f --filter "until=${until_filter}"
    ;;
esac

if [ "$mode" = "hard" ]; then
  echo "Hard cleanup also removes unused local volumes. Use only in local development."
  docker volume prune -f --filter "label!=keep" || true
fi
