#!/usr/bin/env bash
# Install a pinned, checksum-verified Trivy binary.
#
# Replaces `curl .../trivy/main/contrib/install.sh | sh`, which executed an
# unpinned script from a moving branch and installed whatever release was
# latest at the time — a supply-chain hole in the very tool that gates the
# images. Bump TRIVY_VERSION and both SHA-256s together (values come from
# trivy_<ver>_checksums.txt on the GitHub release).
#
# Usage:  scripts/install-trivy.sh [install-dir]   (default: /usr/local/bin)
set -euo pipefail

TRIVY_VERSION="0.76.1"
SHA256_LINUX_AMD64="c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0"
SHA256_LINUX_ARM64="e174dff2a6dba5e3ae41f8d0537a6324405bd08132497340304c6b20e0f16a1f"

INSTALL_DIR="${1:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64|amd64)  ARCH="64bit"; SHA256="${SHA256_LINUX_AMD64}" ;;
  aarch64|arm64) ARCH="ARM64"; SHA256="${SHA256_LINUX_ARM64}" ;;
  *) echo "install-trivy: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

TARBALL="trivy_${TRIVY_VERSION}_Linux-${ARCH}.tar.gz"
URL="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARBALL}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "install-trivy: downloading ${URL}"
curl -fsSL --proto '=https' --tlsv1.2 -o "${WORK}/${TARBALL}" "${URL}"
echo "${SHA256}  ${WORK}/${TARBALL}" | sha256sum -c -
tar -xzf "${WORK}/${TARBALL}" -C "${WORK}" trivy

SUDO=""
[ -w "${INSTALL_DIR}" ] || SUDO="sudo"
${SUDO} install -m 0755 "${WORK}/trivy" "${INSTALL_DIR}/trivy"
"${INSTALL_DIR}/trivy" --version
