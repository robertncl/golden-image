#!/usr/bin/env bash
# Promote published golden images from GHCR (or any registry) to Azure
# Container Registry.
#
# Copies registry-to-registry with `docker buildx imagetools create`: every
# architecture, the provenance/SBOM attestations and the index annotations are
# carried over unchanged, and nothing is pulled into the local image store.
# (The old pull/tag/push sync copied only the runner's own architecture.)
# Optionally re-runs the CIS gate against each source image first.
#
# Usage:
#   scripts/promote-to-acr.sh --acr <name|login-server> [--verify] <image:tag> [...]
#   scripts/promote-to-acr.sh --acr <name> --from-file published.txt
# The destination keeps the repository basename and tag:
#   ghcr.io/acme/nginx-platform:1.30  ->  <acr>.azurecr.io/nginx-platform:1.30
#
# Prerequisites: logged in to both registries (`docker login ghcr.io` for
# private packages; `az acr login --name <acr>` or the CI OIDC login).
# Env: ACR_NAME (instead of --acr), DRY_RUN=1 (print the copies only).
set -euo pipefail
cd "$(dirname "$0")/.."

ACR="${ACR_NAME:-}"; VERIFY=0; IMAGES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --acr)       ACR="$2"; shift ;;
    --verify)    VERIFY=1 ;;
    --from-file) mapfile -t -O "${#IMAGES[@]}" IMAGES < <(grep -v '^[[:space:]]*\(#\|$\)' "$2"); shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    -*)          echo "Unknown option: $1" >&2; exit 2 ;;
    *)           IMAGES+=("$1") ;;
  esac
  shift
done

[ -n "${ACR}" ] || { echo "promote-to-acr: --acr <name> (or ACR_NAME) is required" >&2; exit 2; }
[ "${#IMAGES[@]}" -gt 0 ] || { echo "promote-to-acr: no images given" >&2; exit 2; }
case "${ACR}" in *.*|*:*) LOGIN_SERVER="${ACR}" ;; *) LOGIN_SERVER="${ACR}.azurecr.io" ;; esac

rc=0
for src in "${IMAGES[@]}"; do
  name="${src##*/}"
  case "${name}" in
    *@*) echo "promote-to-acr: ${src}: give a tag, not a digest" >&2; rc=1; continue ;;
    *:*) ;;
    *)   name="${name}:latest" ;;
  esac
  dst="${LOGIN_SERVER}/${name}"

  if [ "${VERIFY}" -eq 1 ] && ! scripts/cis-verify.sh "${src}"; then
    echo "✖ ${src} failed the CIS gate; not promoted" >&2
    rc=1
    continue
  fi

  echo "📦 ${src} -> ${dst}"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "   (dry run) docker buildx imagetools create --tag ${dst} ${src}"
  elif ! docker buildx imagetools create --tag "${dst}" "${src}"; then
    echo "✖ failed to promote ${src}" >&2
    rc=1
  fi
done

[ "${rc}" -eq 0 ] && echo "✅ Promoted ${#IMAGES[@]} image(s) to ${LOGIN_SERVER}."
exit "${rc}"
