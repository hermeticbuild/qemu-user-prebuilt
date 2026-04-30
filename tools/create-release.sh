#!/usr/bin/env bash
set -euo pipefail

TAG="${1:?usage: tools/create-release.sh <tag> <asset>...}"
shift

if (( $# == 0 )); then
    echo "at least one release asset is required" >&2
    exit 1
fi

TITLE="qemu-static ${TAG}"
NOTES="Static Linux user-mode QEMU builds for amd64 and arm64."

if gh release view "${TAG}" >/dev/null 2>&1; then
    gh release upload "${TAG}" "$@" --clobber
else
    gh release create "${TAG}" "$@" --title "${TITLE}" --notes "${NOTES}"
fi
