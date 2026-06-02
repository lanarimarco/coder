#!/usr/bin/env bash
# Usage: ./push-template.sh <template-name> [extra coder args...]
#
# Dereferences the ./modules symlink inside the template directory before
# uploading, because Coder's provisioner does not follow symlinks.
set -euo pipefail

TEMPLATE=${1:?Usage: $0 <template-name> [extra coder args...]}
shift

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -rL "$TEMPLATE/." "$TMPDIR/"

coder template push "$TEMPLATE" --directory "$TMPDIR" "$@"
