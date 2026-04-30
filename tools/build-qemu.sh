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

archive_count="$(find "${OUT_DIR}" -maxdepth 1 -type f \( -name "qemu-user-linux-${ARCH}-*.tar.zst" -o -name "qemu-user-linux-${ARCH}-*.tar.gz" \) | wc -l | tr -d ' ')"
if [[ "${archive_count}" != "2" ]]; then
    echo "expected qemu-user-linux-${ARCH}-*.tar.zst and qemu-user-linux-${ARCH}-*.tar.gz archives, found ${archive_count}" >&2
    find "${OUT_DIR}" -maxdepth 1 -type f -print >&2
    exit 1
fi

binary_count="$(find "${OUT_DIR}" -maxdepth 1 -type f -name "qemu-user-linux-${ARCH}-*" ! -name "*.gz" ! -name "*.zst" ! -name "*.tar.*" | wc -l | tr -d ' ')"
if [[ "${binary_count}" == "0" ]]; then
    echo "expected at least one qemu-user-linux-${ARCH}-<target> binary" >&2
    find "${OUT_DIR}" -maxdepth 1 -type f -print >&2
    exit 1
fi

compressed_binary_count="$(find "${OUT_DIR}" -maxdepth 1 -type f \( -name "qemu-user-linux-${ARCH}-*.gz" -o -name "qemu-user-linux-${ARCH}-*.zst" \) ! -name "*.tar.*" | wc -l | tr -d ' ')"
expected_compressed_binary_count="$((binary_count * 2))"
if [[ "${compressed_binary_count}" != "${expected_compressed_binary_count}" ]]; then
    echo "expected ${expected_compressed_binary_count} compressed qemu-user-linux-${ARCH}-<target> binaries, found ${compressed_binary_count}" >&2
    find "${OUT_DIR}" -maxdepth 1 -type f -print >&2
    exit 1
fi

mapfile -t artifacts < <(find "${OUT_DIR}" -maxdepth 1 -type f \( -name "qemu-user-linux-${ARCH}-*" -o -name "qemu-user-linux-${ARCH}-*.tar.gz" -o -name "qemu-user-linux-${ARCH}-*.tar.zst" \) | sort)

artifact_names=()
for artifact in "${artifacts[@]}"; do
    artifact_name="$(basename "${artifact}")"
    artifact_names+=("${artifact_name}")

    if command -v sha256sum >/dev/null 2>&1; then
        (cd "${OUT_DIR}" && sha256sum "${artifact_name}" > "${artifact_name}.sha256")
    else
        (cd "${OUT_DIR}" && shasum -a 256 "${artifact_name}" > "${artifact_name}.sha256")
    fi

    echo "Artifact: ${artifact}"
    echo "Checksum: ${artifact}.sha256"
done

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "attestation_name=qemu-user-linux-${ARCH}.attestation.jsonl" >> "${GITHUB_OUTPUT}"
fi
