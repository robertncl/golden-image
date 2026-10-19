#!/usr/bin/env bash
# Print the docker-bake.hcl variables defined in configs/*.env as KEY=VALUE
# lines, so local scripts and CI feed bake the same version configuration.
#
# The env files are parsed as data (never `source`d) and only the variables
# bake knows about are emitted. Values already set in the environment win, so
# `DEFAULT_ALPINE_VERSION=3.23 make build` overrides the config file.
#
# Usage:
#   eval "$(scripts/bake-env.sh --export)"   # local shell
#   scripts/bake-env.sh >> "$GITHUB_ENV"     # GitHub Actions
set -euo pipefail
cd "$(dirname "$0")/.."

KEYS=(
  ALPINE_VERSIONS DEBIAN_VERSIONS REDHAT_VERSIONS
  DEFAULT_ALPINE_VERSION DEFAULT_DEBIAN_VERSION DEFAULT_REDHAT_VERSION
  DEFAULT_NGINX_VERSION DEFAULT_PYTHON_VERSION DEFAULT_OPENJDK_VERSION
  DEFAULT_TOMCAT_VERSION DEFAULT_SPRINGBOOT_VERSION DEFAULT_ASPNET_VERSION
  DEFAULT_DOTNET_VERSION
)

declare -A cfg=()
for f in configs/lts-versions.env configs/platform-lts-versions.env; do
  [ -f "$f" ] || continue
  while IFS='=' read -r key value; do
    [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    value="${value%\"}"; value="${value#\"}"
    cfg[$key]="$value"
  done < "$f"
done

prefix=""
[ "${1:-}" = "--export" ] && prefix="export "
for key in "${KEYS[@]}"; do
  value="${!key:-${cfg[$key]:-}}"
  [ -n "$value" ] || continue
  if [ -n "$prefix" ]; then
    printf '%s%s=%q\n' "$prefix" "$key" "$value"
  else
    printf '%s=%s\n' "$key" "$value"
  fi
done
