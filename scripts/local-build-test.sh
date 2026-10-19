#!/usr/bin/env bash
# Build, smoke-test and CIS-verify the golden images locally on Docker Desktop
# — the same graph, gates and checks CI runs, minus the registry push.
#
# Pipeline: Dockerfile CIS lint -> `docker buildx bake` (one parallel graph,
# docker-bake.hcl) -> functional smoke tests -> Trivy CIS gate -> optional
# size/vulnerability report. Images land in the local image store; no registry
# login is needed.
#
# Usage:
#   scripts/local-build-test.sh [options]
# Options:
#   --quick            Default-version Alpine + Debian bases, nginx, python.
#   --targets "<t..>"  Explicit bake targets/groups (e.g. "alpine-3-24 nginx").
#                      Default: "all" (every LTS base + every platform).
#   --platform <list>  Build for these platforms, e.g. linux/amd64 to exercise
#                      the CI architecture under emulation (default: native).
#   --no-cache         Ignore the build cache (cold-build timing).
#   --no-smoke         Skip the functional smoke tests.
#   --no-verify        Skip the CIS lint + Trivy gate.
#   --report <file>    Write a size/vulnerability Markdown report.
#   --print            Show the resolved bake plan and exit.
#   -h | --help        Show this help.
#
# Env: REGISTRY (image prefix, default golden-local), PATCH_EPOCH (default:
# today, UTC), TRIVY_SEVERITY (gate level), any variable in configs/*.env.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGETS=(all); PLATFORM=""; NO_CACHE=(); SMOKE=1; VERIFY=1; REPORT=""; PRINT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)     TARGETS=(default) ;;
    --targets)   read -r -a TARGETS <<< "$2"; shift ;;
    --platform)  PLATFORM="$2"; shift ;;
    --no-cache)  NO_CACHE=(--no-cache) ;;
    --no-smoke)  SMOKE=0 ;;
    --no-verify) VERIFY=0 ;;
    --report)    REPORT="$2"; shift ;;
    --print)     PRINT=1 ;;
    -h|--help)   sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

eval "$(scripts/bake-env.sh --export)"
export REGISTRY="${REGISTRY:-golden-local}"
export PATCH_EPOCH="${PATCH_EPOCH:-$(date -u +%Y%m%d)}"
BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
export BUILD_DATE VCS_REF PLATFORMS="${PLATFORM}"

blue()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

BAKE=(docker buildx bake -f docker-bake.hcl)
if [ "${PRINT}" -eq 1 ]; then
  "${BAKE[@]}" --print "${TARGETS[@]}"
  exit 0
fi

mapfile -t IMAGES < <(scripts/bake-images.sh "${TARGETS[@]}")

if [ "${VERIFY}" -eq 1 ]; then
  blue "🔒 Linting Dockerfiles against CIS build checks..."
  scripts/lint-dockerfiles.sh
fi

blue "🔨 Building ${#IMAGES[@]} image(s) as one graph (patch epoch ${PATCH_EPOCH}${PLATFORM:+, ${PLATFORM}})"
SECONDS=0
"${BAKE[@]}" --load "${NO_CACHE[@]}" "${TARGETS[@]}"
green "✅ Bake graph completed in ${SECONDS}s"
printf '   - %s\n' "${IMAGES[@]}"

if [ "${SMOKE}" -eq 1 ]; then
  blue "🧪 Smoke-testing built images..."
  scripts/smoke-test.sh "${IMAGES[@]}"
fi

if [ "${VERIFY}" -eq 1 ]; then
  blue "🔒 Running CIS verification (Trivy) on all built images..."
  scripts/cis-verify.sh "${IMAGES[@]}"
fi

if [ -n "${REPORT}" ]; then
  blue "📊 Writing size/vulnerability report to ${REPORT}..."
  scripts/image-report.sh "${IMAGES[@]}" > "${REPORT}"
  cat "${REPORT}"
fi
