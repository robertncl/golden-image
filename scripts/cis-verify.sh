#!/usr/bin/env bash
# CIS verification gate for built container images — powered by Trivy only.
#
# Trivy is a single, widely-trusted scanner (no Dockle / no third-party linter
# image is pulled). On each image it checks:
#   * vuln     — OS/library vulnerabilities
#   * secret   — credentials/keys baked into the image (CIS-DI-0010 on the artifact)
#   * misconfig— image configuration issues
# and FAILS (non-zero exit) on any finding at/above TRIVY_SEVERITY.
#
# The Dockerfile build-practice checks that Dockle used to cover (non-root USER,
# COPY-not-ADD, HEALTHCHECK, ...) are enforced separately and earlier by
# scripts/lint-dockerfiles.sh, which runs `trivy config` over the Dockerfiles.
#
# Usage:   scripts/cis-verify.sh <image[:tag]> [<image[:tag]> ...]
# Tunables (env):
#   TRIVY_SEVERITY   default: HIGH,CRITICAL
#   TRIVY_SCANNERS   default: vuln,secret,misconfig
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <image[:tag]> [<image[:tag]> ...]" >&2
  exit 2
fi

TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_SCANNERS="${TRIVY_SCANNERS:-vuln,secret,misconfig}"
TRIVY_VERSION="${TRIVY_VERSION:-0.55.0}"
# Gate only on vulnerabilities that have an available fix — an image already
# patched to the latest packages cannot remediate CVEs upstream hasn't fixed,
# so blocking on them would be unactionable. Set IGNORE_UNFIXED=0 to gate on all.
IGNORE_UNFIXED_FLAG=""
[ "${IGNORE_UNFIXED:-1}" = "1" ] && IGNORE_UNFIXED_FLAG="--ignore-unfixed"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
rc=0

run_trivy() {
  local image="$1"
  echo -e "${BLUE}🔍 Trivy (${TRIVY_SCANNERS}) -> ${image}${NC}"
  if command -v trivy >/dev/null 2>&1; then
    trivy image --scanners "${TRIVY_SCANNERS}" ${IGNORE_UNFIXED_FLAG} \
      --severity "${TRIVY_SEVERITY}" --exit-code 1 --no-progress "${image}"
  else
    # Fall back to the official Trivy image (Trivy publishes a minimal, regularly
    # rebuilt image) if no local binary is available.
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      "aquasec/trivy:${TRIVY_VERSION}" image --scanners "${TRIVY_SCANNERS}" ${IGNORE_UNFIXED_FLAG} \
      --severity "${TRIVY_SEVERITY}" --exit-code 1 --no-progress "${image}"
  fi
}

for image in "$@"; do
  echo -e "${YELLOW}=== CIS verification: ${image} ===${NC}"
  if run_trivy "${image}"; then
    echo -e "${GREEN}✔ ${image} passed CIS verification${NC}"
  else
    echo -e "${RED}✖ ${image} FAILED CIS verification${NC}"
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
