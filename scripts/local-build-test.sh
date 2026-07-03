#!/usr/bin/env bash
# Build and CIS-verify the golden images locally on Docker Desktop.
#
# Uses `docker buildx bake` (docker-bake.hcl) to build everything as ONE
# dependency graph instead of sequential `docker build`s: the three bases and
# the five alpine-derived platforms build in parallel, tomcat/springboot are
# scheduled after openjdk automatically, and every shared layer is built and
# cached exactly once. Images land in the local image store — no registry, no
# GHCR/ACR login and no multi-arch needed — then (optionally) run through
# scripts/cis-verify.sh (Trivy) exactly like CI does.
#
# Usage:
#   scripts/local-build-test.sh [options]
# Options:
#   --base-only        Build only the base OS images.
#   --all-platforms    Also build the heavier platforms (openjdk, tomcat,
#                      springboot, aspnet, dotnet) — these pull JREs/runtimes.
#   --with-redhat      Also build the RedHat UBI base (needs RH registry pull).
#   --no-verify        Skip the Trivy CIS verification step.
#   --print            Show the resolved bake plan (targets, tags) and exit.
#   -h | --help        Show this help.
#
# Env: LOCAL_PREFIX (default: golden-local), gate level via TRIVY_SEVERITY.
set -euo pipefail
cd "$(dirname "$0")/.."

export PREFIX="${LOCAL_PREFIX:-golden-local}"
export BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
export VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
export VERSION="1.0.0"

BASE_ONLY=0; ALL_PLATFORMS=0; WITH_REDHAT=0; VERIFY=1; PRINT=0
for arg in "$@"; do
  case "$arg" in
    --base-only)     BASE_ONLY=1 ;;
    --all-platforms) ALL_PLATFORMS=1 ;;
    --with-redhat)   WITH_REDHAT=1 ;;
    --no-verify)     VERIFY=0 ;;
    --print)         PRINT=1 ;;
    -h|--help)       sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Default versions used for the local build (kept in step with the config).
ALPINE_VER="3.24"; DEBIAN_VER="13"; REDHAT_VER="10"
[ -f configs/lts-versions.env ] && . configs/lts-versions.env || true
export ALPINE_VER="${DEFAULT_ALPINE_VERSION:-$ALPINE_VER}"
export DEBIAN_VER="${DEFAULT_DEBIAN_VERSION:-$DEBIAN_VER}"
export REDHAT_VER="${DEFAULT_REDHAT_VERSION:-$REDHAT_VER}"

blue() { printf '\033[0;34m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

# ---- compose the bake target list (one graph, maximum parallelism) -----------
TARGETS=(base-alpine base-debian)
[ "${WITH_REDHAT}" -eq 1 ] && TARGETS+=(base-redhat)
if [ "${BASE_ONLY}" -eq 0 ]; then
  TARGETS+=(nginx python)
  if [ "${ALL_PLATFORMS}" -eq 1 ]; then
    TARGETS+=(openjdk tomcat springboot aspnet dotnet)
  fi
fi

if [ "${PRINT}" -eq 1 ]; then
  docker buildx bake -f docker-bake.hcl --print "${TARGETS[@]}"
  exit 0
fi

# Dockerfile CIS build-practice gate (fast, runs before any image is built).
if [ "${VERIFY}" -eq 1 ]; then
  blue "🔒 Linting Dockerfiles against CIS build checks..."
  scripts/lint-dockerfiles.sh
fi

blue "🔨 Building ${#TARGETS[@]} target(s) as one parallel graph: ${TARGETS[*]}"
SECONDS=0
docker buildx bake -f docker-bake.hcl --load "${TARGETS[@]}"
green "✅ Bake graph completed in ${SECONDS}s"

# ---- resolve the tags that were just built -----------------------------------
BUILT=()
for t in "${TARGETS[@]}"; do
  case "$t" in
    base-alpine) BUILT+=("${PREFIX}/alpine-hardened:${ALPINE_VER}") ;;
    base-debian) BUILT+=("${PREFIX}/debian-hardened:${DEBIAN_VER}") ;;
    base-redhat) BUILT+=("${PREFIX}/redhat-hardened:${REDHAT_VER}") ;;
    *)           BUILT+=("${PREFIX}/${t}-platform:local") ;;
  esac
done
green "✅ Built ${#BUILT[@]} image(s):"
printf '   - %s\n' "${BUILT[@]}"

# ---- CIS verification ---------------------------------------------------------
if [ "${VERIFY}" -eq 1 ]; then
  blue "🔒 Running CIS verification (Trivy) on all built images..."
  scripts/cis-verify.sh "${BUILT[@]}"
else
  echo "Skipping CIS verification (--no-verify)."
fi
