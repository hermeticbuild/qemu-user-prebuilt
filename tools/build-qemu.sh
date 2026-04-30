#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:?usage: tools/build-qemu.sh <amd64|arm64>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
IMAGE="qemu-static-${ARCH}:build"
CONTAINER="qemu-static-${ARCH}-copy-$$"

case "${ARCH}" in
    amd64)
        PLATFORM="linux/amd64"
        ;;
    arm64)
        PLATFORM="linux/arm64"
        ;;
    *)
        echo "unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

cleanup() {
    docker container rm "${CONTAINER}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

mkdir -p "${OUT_DIR}"

docker build \
    --platform "${PLATFORM}" \
    --tag "${IMAGE}" \
    "${ROOT_DIR}"

docker create --name "${CONTAINER}" "${IMAGE}" true >/dev/null
docker cp "${CONTAINER}:/work/artifact/." "${OUT_DIR}/"

artifact_count="$(find "${OUT_DIR}" -maxdepth 1 -type f -name "qemu-linux-${ARCH}-*.tar.xz" | wc -l | tr -d ' ')"
if [[ "${artifact_count}" != "1" ]]; then
    echo "expected exactly one qemu-linux-${ARCH}-*.tar.xz artifact, found ${artifact_count}" >&2
    find "${OUT_DIR}" -maxdepth 1 -type f -print >&2
    exit 1
fi

artifact="$(find "${OUT_DIR}" -maxdepth 1 -type f -name "qemu-linux-${ARCH}-*.tar.xz" | sort | head -n 1)"

if command -v sha256sum >/dev/null 2>&1; then
    (cd "${OUT_DIR}" && sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256")
else
    (cd "${OUT_DIR}" && shasum -a 256 "$(basename "${artifact}")" > "$(basename "${artifact}").sha256")
fi

echo "Artifact: ${artifact}"
echo "Checksum: ${artifact}.sha256"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "artifact_name=$(basename "${artifact}")" >> "${GITHUB_OUTPUT}"
fi
