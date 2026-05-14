#!/usr/bin/env bash
set -euo pipefail

DEPLOY_TARGET_ENV="${1:-${DEPLOY_ENV:-dev}}"
RELEASE_STATE_ROOT="${RELEASE_STATE_ROOT:-${HOME}/.app-starter-infra/releases}"

printf '%s/%s\n' "${RELEASE_STATE_ROOT}" "${DEPLOY_TARGET_ENV}"
