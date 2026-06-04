#!/usr/bin/env bash
# Usage: ./new-template.sh <template-name>
#
# Scaffolds a new Coder template directory that calls the shared
# modules/jardis-workspace module. Prompts for the required values.
#
# <template-name> should match the kokos application name (e.g. smeuperp, demo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
if [ -f "$SCRIPT_DIR/.env" ]; then
  # Export only the DEFAULT_* vars we care about, ignore the rest
  set -a
  # shellcheck disable=SC1090
  source <(grep -E '^DEFAULT_(JARDIS_HOST|JARDIS_PORT|USERS_WORKSPACE_PATH)=' "$SCRIPT_DIR/.env")
  set +a
fi

TEMPLATE=${1:?Usage: $0 <template-name>}

if [ -d "$TEMPLATE" ]; then
  echo "Error: directory '$TEMPLATE' already exists." >&2
  exit 1
fi

echo "Creating template '$TEMPLATE'"
echo ""

DEFAULT_ENV="${TEMPLATE}-user"
DEFAULT_PATH="${DEFAULT_USERS_WORKSPACE_PATH:-/home/kokos/users-workspace}"

HOST_PROMPT="jardis_host"
[ -n "${DEFAULT_JARDIS_HOST:-}" ] && HOST_PROMPT+=" [${DEFAULT_JARDIS_HOST}]"
read -rp "${HOST_PROMPT}: " JARDIS_HOST
JARDIS_HOST="${JARDIS_HOST:-${DEFAULT_JARDIS_HOST:-}}"

PORT_PROMPT="jardis_port"
[ -n "${DEFAULT_JARDIS_PORT:-}" ] && PORT_PROMPT+=" [${DEFAULT_JARDIS_PORT}]"
read -rp "${PORT_PROMPT}: " JARDIS_PORT
JARDIS_PORT="${JARDIS_PORT:-${DEFAULT_JARDIS_PORT:-}}"

read -rp "jardis_env           [${DEFAULT_ENV}]: " JARDIS_ENV
JARDIS_ENV="${JARDIS_ENV:-$DEFAULT_ENV}"
read -rp "users_workspace_path [${DEFAULT_PATH}]: " USERS_WORKSPACE_PATH
USERS_WORKSPACE_PATH="${USERS_WORKSPACE_PATH:-$DEFAULT_PATH}"

echo ""
echo "Enter repo names one per line (empty line to finish):"
REPOS=()
while IFS= read -rp "  repo: " REPO && [ -n "$REPO" ]; do
  REPOS+=("$REPO")
done

if [ ${#REPOS[@]} -eq 0 ]; then
  echo "Error: at least one repo is required." >&2
  exit 1
fi

mkdir -p "$TEMPLATE"
ln -sfn ../modules "$TEMPLATE/modules"

cat > "$TEMPLATE/main.tf" <<EOF
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}
provider "coder" {}

module "workspace" {
  source = "./modules/jardis-workspace"

  jardis_host          = "$JARDIS_HOST"
  jardis_port          = $JARDIS_PORT
  jardis_env           = "$JARDIS_ENV"
  users_workspace_path = "$USERS_WORKSPACE_PATH"
  workspace_dir        = "$TEMPLATE"
  repos = [
$(for REPO in "${REPOS[@]}"; do echo "    \"$REPO\","; done)
  ]
}
EOF

echo ""
echo "Template '$TEMPLATE' created:"
echo "  $TEMPLATE/main.tf"
echo "  $TEMPLATE/modules -> ../modules  (symlink)"
echo ""
echo "Next steps:"
echo "  Review $TEMPLATE/main.tf, then push with:"
echo "  ./push-template.sh $TEMPLATE"
