#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-project.sh --project-name <name> --github-owner <owner> [options]

Options:
  --project-name <name>       Project slug, for example: my-app
  --github-owner <name>       GitHub owner, for example: my-org
  --back-repo <name>          Backend repository name, default: <project>-back
  --front-repo <name>         Frontend repository name, default: <project>-front
  --infra-repo <name>         Infra repository name, default: <project>-infra
  --back-dir <path>           Backend repo directory, default: sibling app-starter-back or ../<back-repo>
  --front-dir <path>          Frontend repo directory, default: sibling app-starter-front or ../<front-repo>
  --infra-dir <path>          Infra repo directory, default: current repo
  --registry <value>          Container registry prefix, default: ghcr.io/<owner>
  --configure-git-remotes     Replace origin in each repo with the target GitHub repository
  --skip-init                 Skip local file generation via scripts/init.sh
  --skip-checks               Skip prerequisite command checks
  --help                      Show this help
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

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

require_repo() {
  local repo_dir="$1"
  local script_path="$2"

  if [ ! -d "$repo_dir" ]; then
    echo "Expected repository directory not found: $repo_dir" >&2
    exit 1
  fi

  if [ ! -f "${repo_dir}/${script_path}" ]; then
    echo "Expected script not found: ${repo_dir}/${script_path}" >&2
    exit 1
  fi
}

resolve_default_repo_dir() {
  local parent_dir="$1"
  local starter_dir_name="$2"
  local target_dir_name="$3"
  local starter_dir="${parent_dir}/${starter_dir_name}"
  local target_dir="${parent_dir}/${target_dir_name}"

  if [ -d "$starter_dir" ] && [ ! -d "$target_dir" ]; then
    printf '%s\n' "$starter_dir"
    return 0
  fi

  printf '%s\n' "$target_dir"
}

configure_origin_remote() {
  local repo_dir="$1"
  local remote_url="$2"

  if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$repo_dir" remote set-url origin "$remote_url"
    return 0
  fi

  git -C "$repo_dir" remote add origin "$remote_url"
}

PROJECT_NAME=""
GITHUB_OWNER=""
BACK_REPO=""
FRONT_REPO=""
INFRA_REPO=""
BACK_DIR=""
FRONT_DIR=""
INFRA_DIR="$ROOT_DIR"
REGISTRY=""
CONFIGURE_GIT_REMOTES=0
SKIP_INIT=0
SKIP_CHECKS=0

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
    --back-dir)
      require_value "$1" "${2:-}"
      BACK_DIR="$2"
      shift 2
      ;;
    --front-dir)
      require_value "$1" "${2:-}"
      FRONT_DIR="$2"
      shift 2
      ;;
    --infra-dir)
      require_value "$1" "${2:-}"
      INFRA_DIR="$2"
      shift 2
      ;;
    --registry)
      require_value "$1" "${2:-}"
      REGISTRY="$2"
      shift 2
      ;;
    --configure-git-remotes)
      CONFIGURE_GIT_REMOTES=1
      shift
      ;;
    --skip-init)
      SKIP_INIT=1
      shift
      ;;
    --skip-checks)
      SKIP_CHECKS=1
      shift
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
INFRA_DIR="$(cd "${INFRA_DIR}" && pwd)"
WORKSPACE_DIR="$(cd "${INFRA_DIR}/.." && pwd)"

if [ -z "$BACK_DIR" ]; then
  BACK_DIR="$(resolve_default_repo_dir "$WORKSPACE_DIR" "app-starter-back" "$BACK_REPO")"
fi

if [ -z "$FRONT_DIR" ]; then
  FRONT_DIR="$(resolve_default_repo_dir "$WORKSPACE_DIR" "app-starter-front" "$FRONT_REPO")"
fi

if [ "$SKIP_CHECKS" -ne 1 ]; then
  if [ "$SKIP_INIT" -ne 1 ]; then
    require_command openssl
  fi

  if [ "$CONFIGURE_GIT_REMOTES" -eq 1 ]; then
    require_command git
  fi
fi

require_repo "$BACK_DIR" "scripts/init-project.sh"
require_repo "$FRONT_DIR" "scripts/init-project.sh"
require_repo "$INFRA_DIR" "scripts/init-project.sh"

"${BACK_DIR}/scripts/init-project.sh" \
  --project-name "$PROJECT_NAME" \
  --github-owner "$GITHUB_OWNER" \
  --back-repo "$BACK_REPO" \
  --front-repo "$FRONT_REPO" \
  --infra-repo "$INFRA_REPO"

"${FRONT_DIR}/scripts/init-project.sh" \
  --project-name "$PROJECT_NAME" \
  --github-owner "$GITHUB_OWNER" \
  --back-repo "$BACK_REPO" \
  --front-repo "$FRONT_REPO" \
  --infra-repo "$INFRA_REPO"

"${INFRA_DIR}/scripts/init-project.sh" \
  --project-name "$PROJECT_NAME" \
  --github-owner "$GITHUB_OWNER" \
  --back-repo "$BACK_REPO" \
  --front-repo "$FRONT_REPO" \
  --infra-repo "$INFRA_REPO" \
  --registry "$REGISTRY"

if [ "$SKIP_INIT" -ne 1 ]; then
  "${BACK_DIR}/scripts/init.sh"
  "${FRONT_DIR}/scripts/init.sh"
  "${INFRA_DIR}/scripts/init.sh" "${PROJECT_NAME}.localhost"
fi

if [ "$CONFIGURE_GIT_REMOTES" -eq 1 ]; then
  configure_origin_remote "$BACK_DIR" "https://github.com/${GITHUB_OWNER}/${BACK_REPO}.git"
  configure_origin_remote "$FRONT_DIR" "https://github.com/${GITHUB_OWNER}/${FRONT_REPO}.git"
  configure_origin_remote "$INFRA_DIR" "https://github.com/${GITHUB_OWNER}/${INFRA_REPO}.git"
fi

cat <<EOF
Bootstrap completed for ${PROJECT_NAME}.

Repositories:
- back: ${BACK_DIR}
- front: ${FRONT_DIR}
- infra: ${INFRA_DIR}

GitHub repositories:
- https://github.com/${GITHUB_OWNER}/${BACK_REPO}
- https://github.com/${GITHUB_OWNER}/${FRONT_REPO}
- https://github.com/${GITHUB_OWNER}/${INFRA_REPO}

Remaining manual work:
1. Create the GitHub repositories if they do not exist yet.
2. Review the generated .env and bootstrap files for real secrets and environment values.
3. Run the relevant containerized checks before first push.
EOF
