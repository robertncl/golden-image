#!/usr/bin/env bash
# Print the image refs a bake invocation produces, one per line: the first tag
# of every requested target. Targets pulled in only as a build context (e.g.
# the Alpine base behind `platforms`) resolve to a cacheonly output and are
# skipped. Reads the same environment as the build (REGISTRY, *_VERSIONS, ...).
#
# Usage:   scripts/bake-images.sh <target|group> [...]
set -euo pipefail
cd "$(dirname "$0")/.."

docker buildx bake -f docker-bake.hcl --print "${@:-default}" 2>/dev/null |
  jq -r '.target | to_entries[]
         | select((.value.output // [])[0].type != "cacheonly")
         | .value.tags[0]' | sort
