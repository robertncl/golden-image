#!/usr/bin/env bash
# Merge per-architecture image digests into tagged multi-arch manifest lists.
#
# Each CI build leg (one native runner per architecture) pushes its images by
# digest only and records them in a bake metadata file. This stitches the
# digests of every target into one index per tag with
# `docker buildx imagetools create`, entirely registry-side: provenance and SBOM
# attestations are carried over and nothing is pulled.
#
# Usage:   scripts/ci/merge-manifests.sh <metadata-dir> <target|group> [...]
#   <metadata-dir>  one bake --metadata-file JSON per architecture
# Env:     the bake variables of the build (REGISTRY, TAG_SUFFIXES,
#          PUBLISH_LATEST, *_VERSIONS, ...), SOURCE_URL, VCS_REF, BUILD_DATE.
# Output:  published.txt (every tag pushed) and primary.txt (first tag of each
#          image) in the current directory.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <metadata-dir> <target|group> [...]" >&2
  exit 2
fi
META_DIR="$1"; shift
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

shopt -s nullglob
META=("${META_DIR}"/*.json)
[ "${#META[@]}" -gt 0 ] || { echo "merge-manifests: no metadata in ${META_DIR}" >&2; exit 1; }

# The tag plan: the same graph resolved WITHOUT push-by-digest gives every
# target's final tags.
plan="$(PUSH_BY_DIGEST=false docker buildx bake -f "${ROOT}/docker-bake.hcl" --print "$@" 2>/dev/null)"
mapfile -t targets < <(jq -r '.target | to_entries[]
  | select((.value.output // [])[0].type != "cacheonly") | .key' <<< "${plan}")

: > published.txt
: > primary.txt
for target in "${targets[@]}"; do
  mapfile -t tags < <(jq -r --arg t "${target}" '.target[$t].tags[]' <<< "${plan}")
  repo="${tags[0]%:*}"

  sources=()
  for m in "${META[@]}"; do
    digest="$(jq -r --arg t "${target}" '.[$t]["containerimage.digest"] // empty' "${m}")"
    if [ -z "${digest}" ]; then
      echo "merge-manifests: no digest for ${target} in ${m}" >&2
      exit 1
    fi
    sources+=("${repo}@${digest}")
  done

  args=()
  for t in "${tags[@]}"; do args+=(--tag "${t}"); done
  echo "🔗 ${target}: ${#sources[@]} arch(es) -> ${tags[*]}"
  docker buildx imagetools create "${args[@]}" \
    --annotation "index:org.opencontainers.image.source=${SOURCE_URL:-}" \
    --annotation "index:org.opencontainers.image.revision=${VCS_REF:-}" \
    --annotation "index:org.opencontainers.image.created=${BUILD_DATE:-}" \
    "${sources[@]}"

  printf '%s\n' "${tags[@]}" >> published.txt
  echo "${tags[0]}" >> primary.txt
done

echo "✅ Published $(wc -l < published.txt) tag(s) for ${#targets[@]} image(s)."
