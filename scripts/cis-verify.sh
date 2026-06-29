#!/usr/bin/env bash
# CIS verification gate for container images.
#
# Runs two complementary checks against a built image and FAILS (non-zero exit)
# if either finds a violation at/above the configured threshold:
#
#   1. Dockle  — CIS Docker Benchmark v1.7.0 / CIS Docker-Image (CIS-DI) linting
#                (non-root user, no setuid/setgid, HEALTHCHECK, COPY-not-ADD,
#                 no embedded secrets/credentials, ...).
#   2. Trivy   — vulnerabilities + leaked secrets + Dockerfile misconfigurations.
#
# Both tools are used from a local binary when present, otherwise via their
# official container images, so this works the same locally and in CI.
#
# Usage:   scripts/cis-verify.sh <image[:tag]> [<image[:tag]> ...]
# Tunables (env):
#   DOCKLE_EXIT_LEVEL   info|warn|fatal   (default: warn  -> WARN and above fail)
#   DOCKLE_IGNORE       comma list of checks to ignore (default: CIS-DI-0005)
#   TRIVY_SEVERITY      default: HIGH,CRITICAL
#   SKIP_DOCKLE / SKIP_TRIVY   set to 1 to skip a tool
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <image[:tag]> [<image[:tag]> ...]" >&2
  exit 2
fi

DOCKLE_EXIT_LEVEL="${DOCKLE_EXIT_LEVEL:-warn}"
# CIS-DI-0005 (Content Trust) is satisfied at push time via image signing
# (cosign/notation), not inside the image, so it is ignored by the image linter.
DOCKLE_IGNORE="${DOCKLE_IGNORE:-CIS-DI-0005}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
# Dockle is used as a STATIC BINARY (not the goodwithtech/dockle container image,
# which itself carries vulnerabilities). The binary is reused from PATH if
# present, otherwise downloaded once from the official GitHub release.
DOCKLE_VERSION="${DOCKLE_VERSION:-0.4.14}"
DOCKLE_CACHE="${DOCKLE_CACHE:-${TMPDIR:-/tmp}/golden-dockle}"
TRIVY_VERSION="${TRIVY_VERSION:-0.55.0}"

ensure_dockle() {
  if command -v dockle >/dev/null 2>&1; then DOCKLE_BIN="dockle"; return 0; fi
  if [ -x "${DOCKLE_CACHE}/dockle" ]; then DOCKLE_BIN="${DOCKLE_CACHE}/dockle"; return 0; fi
  local asset
  case "$(uname -m)" in
    x86_64|amd64)  asset="Linux-64bit" ;;
    aarch64|arm64) asset="Linux-ARM64" ;;
    *) echo "Unsupported arch for Dockle: $(uname -m)" >&2; return 1 ;;
  esac
  mkdir -p "${DOCKLE_CACHE}"
  echo "  (fetching dockle ${DOCKLE_VERSION} static binary — no vulnerable image pulled)"
  curl -fsSL "https://github.com/goodwithtech/dockle/releases/download/v${DOCKLE_VERSION}/dockle_${DOCKLE_VERSION}_${asset}.tar.gz" \
    | tar -xz -C "${DOCKLE_CACHE}" dockle
  DOCKLE_BIN="${DOCKLE_CACHE}/dockle"
}

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
rc=0

run_dockle() {
  local image="$1"
  echo -e "${BLUE}🔒 Dockle (CIS-Docker / CIS-DI) -> ${image}${NC}"
  ensure_dockle || return 1
  "${DOCKLE_BIN}" --exit-code 1 --exit-level "${DOCKLE_EXIT_LEVEL}" --ignore "${DOCKLE_IGNORE}" "${image}"
}

run_trivy() {
  local image="$1"
  echo -e "${BLUE}🔍 Trivy (vuln + secret + misconfig) -> ${image}${NC}"
  if command -v trivy >/dev/null 2>&1; then
    trivy image --scanners vuln,secret,misconfig \
      --severity "${TRIVY_SEVERITY}" --exit-code 1 --no-progress "${image}"
  else
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "aquasec/trivy:${TRIVY_VERSION}" image --scanners vuln,secret,misconfig \
      --severity "${TRIVY_SEVERITY}" --exit-code 1 --no-progress "${image}"
  fi
}

for image in "$@"; do
  echo -e "${YELLOW}=== CIS verification: ${image} ===${NC}"
  ok=1
  if [ "${SKIP_DOCKLE:-0}" != "1" ]; then
    run_dockle "${image}" || { echo -e "${RED}✖ Dockle failed for ${image}${NC}"; ok=0; }
  fi
  if [ "${SKIP_TRIVY:-0}" != "1" ]; then
    run_trivy "${image}" || { echo -e "${RED}✖ Trivy failed for ${image}${NC}"; ok=0; }
  fi
  if [ "${ok}" -eq 1 ]; then
    echo -e "${GREEN}✔ ${image} passed CIS verification${NC}"
  else
    rc=1
  fi
  echo ""
done

if [ "${rc}" -ne 0 ]; then
  echo -e "${RED}CIS verification FAILED — non-compliant image(s) detected.${NC}" >&2
else
  echo -e "${GREEN}All images passed CIS verification.${NC}"
fi
exit "${rc}"
