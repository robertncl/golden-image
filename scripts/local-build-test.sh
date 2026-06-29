#!/usr/bin/env bash
# Build and CIS-verify the golden images locally on Docker Desktop.
#
# No registry, no GHCR/ACR login and no multi-arch needed: every image is built
# for the local platform and tagged under a local prefix, then (optionally) run
# through scripts/cis-verify.sh (Dockle + Trivy) exactly like CI does.
#
# Usage:
#   scripts/local-build-test.sh [options]
# Options:
#   --base-only        Build only the base OS images.
#   --all-platforms    Also build the heavier platforms (openjdk, tomcat,
#                      springboot, aspnet, dotnet) — these pull JREs/runtimes.
#   --with-redhat      Also build the RedHat UBI 9 base (needs RH registry pull).
#   --no-verify        Skip the Dockle/Trivy CIS verification step.
#   -h | --help        Show this help.
#
# Env: LOCAL_PREFIX (default: golden-local), VERIFY level via DOCKLE_EXIT_LEVEL.
set -euo pipefail
cd "$(dirname "$0")/.."

PREFIX="${LOCAL_PREFIX:-golden-local}"
BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
VERSION="1.0.0"
BUILD_ARGS=(--build-arg "BUILD_DATE=${BUILD_DATE}" --build-arg "VCS_REF=${VCS_REF}" --build-arg "VERSION=${VERSION}")

BASE_ONLY=0; ALL_PLATFORMS=0; WITH_REDHAT=0; VERIFY=1
for arg in "$@"; do
  case "$arg" in
    --base-only)     BASE_ONLY=1 ;;
    --all-platforms) ALL_PLATFORMS=1 ;;
    --with-redhat)   WITH_REDHAT=1 ;;
    --no-verify)     VERIFY=0 ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Default versions used for the local build (kept in step with the config).
ALPINE_VER="3.24"; DEBIAN_VER="13"; REDHAT_VER="10"
[ -f configs/lts-versions.env ] && . configs/lts-versions.env || true
ALPINE_VER="${DEFAULT_ALPINE_VERSION:-$ALPINE_VER}"
DEBIAN_VER="${DEFAULT_DEBIAN_VERSION:-$DEBIAN_VER}"
REDHAT_VER="${DEFAULT_REDHAT_VERSION:-$REDHAT_VER}"

export DOCKER_BUILDKIT=1
BUILT=()

# Dockerfile CIS build-practice gate (fast, runs before any image is built).
if [ "${VERIFY}" -eq 1 ]; then
  printf '\033[0;34m🔒 Linting Dockerfiles against CIS build checks...\033[0m\n'
  scripts/lint-dockerfiles.sh
fi

blue() { printf '\033[0;34m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

build_base() {  # os version dockerfile
  local os="$1" ver="$2" file="$3" tag="${PREFIX}/$1-hardened:$2"
  blue "🔨 Building base ${tag}"
  docker build "${BUILD_ARGS[@]}" -f "${file}" -t "${tag}" .
  BUILT+=("${tag}")
}

build_platform() {  # name base_tag dockerfile [extra build args...]
  local name="$1" base="$2" file="$3"; shift 3
  local tag="${PREFIX}/${name}-platform:local"
  blue "🔨 Building platform ${tag}  (base: ${base})"
  docker build "${BUILD_ARGS[@]}" --build-arg "BASE_IMAGE=${base}" "$@" -f "${file}" -t "${tag}" .
  BUILT+=("${tag}")
}

# ---- base images -----------------------------------------------------------
build_base alpine "${ALPINE_VER}" "base-images/alpine/Dockerfile.${ALPINE_VER}"
build_base debian "${DEBIAN_VER}" "base-images/debian/Dockerfile.${DEBIAN_VER}"
[ "${WITH_REDHAT}" -eq 1 ] && build_base redhat "${REDHAT_VER}" "base-images/redhat/Dockerfile.${REDHAT_VER}"

ALPINE_BASE="${PREFIX}/alpine-hardened:${ALPINE_VER}"
DEBIAN_BASE="${PREFIX}/debian-hardened:${DEBIAN_VER}"
OPENJDK_IMG="${PREFIX}/openjdk-platform:local"

# ---- platform images -------------------------------------------------------
if [ "${BASE_ONLY}" -eq 0 ]; then
  build_platform nginx  "${ALPINE_BASE}" platform-images/nginx/Dockerfile
  build_platform python "${ALPINE_BASE}" platform-images/python/Dockerfile

  if [ "${ALL_PLATFORMS}" -eq 1 ]; then
    build_platform openjdk    "${DEBIAN_BASE}" platform-images/openjdk/Dockerfile
    build_platform tomcat     "${OPENJDK_IMG}" platform-images/tomcat/Dockerfile
    build_platform springboot "${OPENJDK_IMG}" platform-images/springboot/Dockerfile
    build_platform aspnet     "${DEBIAN_BASE}" platform-images/aspnet/Dockerfile
    build_platform dotnet     "${DEBIAN_BASE}" platform-images/dotnet/Dockerfile
  fi
fi

green "✅ Built ${#BUILT[@]} image(s):"
printf '   - %s\n' "${BUILT[@]}"

# ---- CIS verification ------------------------------------------------------
if [ "${VERIFY}" -eq 1 ]; then
  blue "🔒 Running CIS verification (Dockle + Trivy) on all built images..."
  scripts/cis-verify.sh "${BUILT[@]}"
else
  echo "Skipping CIS verification (--no-verify)."
fi
