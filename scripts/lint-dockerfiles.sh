#!/usr/bin/env bash
# Dockerfile CIS build-practice gate — powered by Trivy's config scanner.
#
# `trivy config` lints the Dockerfiles against Aqua's built-in Docker checks
# (the AVD-DS-* rules), which cover the CIS Docker Benchmark image-build items
# Dockle used to check: non-root final USER (DS-0002), COPY-instead-of-ADD
# (DS-0005), HEALTHCHECK present (DS-0026), no `latest` base tag, no secrets in
# ENV, etc. It FAILS (non-zero) on any finding at/above TRIVY_SEVERITY.
#
# Usage:   scripts/lint-dockerfiles.sh [dir ...]   (default: base-images platform-images)
# Tunables: TRIVY_SEVERITY (default HIGH,CRITICAL)
set -euo pipefail

TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
DIRS=("$@")
[ "${#DIRS[@]}" -eq 0 ] && DIRS=(base-images platform-images)

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
rc=0

scan_dir() {
  local dir="$1"
  echo -e "${BLUE}🔒 trivy config (CIS Docker build checks) -> ${dir}${NC}"
  if command -v trivy >/dev/null 2>&1; then
    trivy config --severity "${TRIVY_SEVERITY}" --exit-code 1 "${dir}"
  else
    docker run --rm -v "$(pwd):/work" -w /work \
      "aquasec/trivy:${TRIVY_VERSION:-0.55.0}" config \
      --severity "${TRIVY_SEVERITY}" --exit-code 1 "${dir}"
  fi
}

for d in "${DIRS[@]}"; do
  if [ ! -e "$d" ]; then echo "skip (missing): $d"; continue; fi
  if scan_dir "$d"; then
    echo -e "${GREEN}✔ ${d} Dockerfiles pass CIS build checks${NC}"
  else
    echo -e "${RED}✖ ${d} has CIS Dockerfile violations${NC}"
    rc=1
  fi
  echo ""
done

if [ "${rc}" -ne 0 ]; then
  echo -e "${RED}Dockerfile CIS lint FAILED.${NC}" >&2
else
  echo -e "${GREEN}All Dockerfiles pass CIS build checks.${NC}"
fi
exit "${rc}"
