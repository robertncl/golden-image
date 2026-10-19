#!/usr/bin/env bash
# Publish golden images from a workstation (Docker Desktop) to a registry —
# the manual counterpart of the CI pipeline, with the same rule: nothing is
# pushed until every image passed the smoke tests and the CIS gate.
#
#   1. per platform: build + load under a throwaway prefix, CIS-gate it (and
#      smoke-test it on the native platform)
#   2. one multi-platform `bake --push` to the real registry with provenance
#      and SBOM attestations (served from the cache warmed in step 1)
#   3. optionally promote the pushed tags to Azure Container Registry
#
# Usage:
#   scripts/publish.sh --registry ghcr.io/<owner> [options]
# Options:
#   --registry <prefix>  Destination repository prefix. Required. E.g.
#                        ghcr.io/robertncl or myacr.azurecr.io
#   --targets "<t..>"    Bake targets/groups. Default: all
#   --platforms <list>   Default: linux/amd64,linux/arm64 (non-native ones
#                        build under QEMU emulation — slower)
#   --latest             Also tag the default flavours as latest.
#   --acr <name>         After pushing, promote every tag to this ACR.
#   --yes                Don't ask for confirmation before pushing.
# Log in first: `echo $CR_PAT | docker login ghcr.io -u <user> --password-stdin`
# and/or `az acr login --name <acr>`.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST=""; TARGETS=(all); PLATFORM_LIST="linux/amd64,linux/arm64"; LATEST=false; ACR=""; YES=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --registry)  DEST="$2"; shift ;;
    --targets)   read -r -a TARGETS <<< "$2"; shift ;;
    --platforms) PLATFORM_LIST="$2"; shift ;;
    --latest)    LATEST=true ;;
    --acr)       ACR="$2"; shift ;;
    --yes)       YES=1 ;;
    -h|--help)   sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "${DEST}" ] || { echo "publish: --registry is required (e.g. ghcr.io/<owner>)" >&2; exit 2; }
DEST="$(echo "${DEST}" | tr '[:upper:]' '[:lower:]')"

blue()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

eval "$(scripts/bake-env.sh --export)"
export PATCH_EPOCH="${PATCH_EPOCH:-$(date -u +%Y%m%d)}"
BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
VCS_REF="$(git rev-parse HEAD)"
SOURCE_URL="https://github.com/$(git remote get-url origin | sed -E 's#(git@|https://)github.com[:/]##; s#\.git$##')"
export BUILD_DATE VCS_REF SOURCE_URL
BAKE=(docker buildx bake -f docker-bake.hcl)
native="linux/$(docker version -f '{{.Server.Arch}}')"

if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  Working tree has uncommitted changes; the images will be labelled ${VCS_REF:0:7} anyway." >&2
fi

scripts/lint-dockerfiles.sh

# ---- 1. gate every platform before anything leaves the machine -------------
IFS=',' read -r -a PLATS <<< "${PLATFORM_LIST}"
for p in "${PLATS[@]}"; do
  arch="${p#*/}"; arch="${arch//\//-}"
  blue "🔨 [${p}] build + gate"
  export REGISTRY="golden-gate-${arch}" PLATFORMS="${p}"
  "${BAKE[@]}" --load "${TARGETS[@]}"
  mapfile -t images < <(scripts/bake-images.sh "${TARGETS[@]}")
  if [ "${p}" = "${native}" ]; then
    scripts/smoke-test.sh "${images[@]}"
  else
    echo "   (smoke tests run on the native ${native} only; ${p} is emulated)"
  fi
  scripts/cis-verify.sh "${images[@]}"
done

# ---- 2. push --------------------------------------------------------------
export REGISTRY="${DEST}" PLATFORMS="${PLATFORM_LIST}" ATTEST=true PUBLISH_LATEST="${LATEST}"
export TAG_SUFFIXES="${PATCH_EPOCH},sha-${VCS_REF:0:7}"
mapfile -t tags < <("${BAKE[@]}" --print "${TARGETS[@]}" 2>/dev/null |
  jq -r '.target[] | select((.output // [])[0].type != "cacheonly") | .tags[]' | sort)
blue "📤 About to push ${#tags[@]} tag(s) to ${DEST} for ${PLATFORM_LIST}:"
printf '   %s\n' "${tags[@]}"
if [ "${YES}" -ne 1 ]; then
  read -r -p "Push? [y/N] " answer
  [[ "${answer}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi
"${BAKE[@]}" --push "${TARGETS[@]}"
green "✅ Pushed to ${DEST}"

# ---- 3. optional ACR promotion ---------------------------------------------
if [ -n "${ACR}" ]; then
  scripts/promote-to-acr.sh --acr "${ACR}" "${tags[@]}"
fi
