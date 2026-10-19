#!/usr/bin/env bash
# Functional smoke tests for built golden images (Docker Desktop or CI).
#
# The CIS gate (cis-verify.sh) proves an image is clean; this proves it WORKS.
# Every image is checked for:
#   * non-root config user (appuser) and runtime uid 10001
#   * no setuid/setgid binaries, no build-script mount stub left behind
#   * a HEALTHCHECK that actually turns healthy, with all capabilities dropped
#     and no-new-privileges (so a broken health command can't ship)
# plus a runtime-specific check chosen from the repository name
# (nginx serves /health with security headers, Tomcat answers HTTP, Python
# can bootstrap pip into its venv, the JRE and .NET runtimes start, ...).
#
# Usage:   scripts/smoke-test.sh <image[:tag]> [...]
# Env:     SMOKE_TIMEOUT  seconds to wait for a container to turn healthy (90)
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <image[:tag]> [<image[:tag]> ...]" >&2
  exit 2
fi

TIMEOUT="${SMOKE_TIMEOUT:-90}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
rc=0
# Detached containers carry a per-run label so cleanup finds them all (start()
# runs in a $(...) subshell, so it can't record them in a variable here).
RUN_LABEL="golden-smoke=$$-${RANDOM}"
cleanup() { docker ps -aq --filter "label=${RUN_LABEL}" | xargs -r docker rm -f >/dev/null 2>&1 || true; }
trap cleanup EXIT

pass() { echo -e "  ${GREEN}✔${NC} $*"; }
fail() { echo -e "  ${RED}✖${NC} $*"; rc=1; }

# check <description> <command...> — pass if the command exits 0.
check() {
  local desc="$1" out; shift
  if out="$("$@" 2>&1)"; then pass "${desc}"; else fail "${desc}"; printf '%s\n' "${out}" | tail -5 | sed 's/^/      /'; fi
}

run() { docker run --rm --cap-drop ALL --security-opt no-new-privileges "$@"; }

# start <image> [docker-run-args... --] [cmd...] — detached, hardened runtime.
start() {
  local image="$1"; shift
  local args=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do args+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  docker run -d --label "${RUN_LABEL}" --cap-drop ALL --security-opt no-new-privileges \
    --health-interval=1s --health-start-period="${TIMEOUT}s" "${args[@]}" "${image}" "$@"
}

# healthy <container> — wait until Docker reports the HEALTHCHECK as healthy.
healthy() {
  local cid="$1" status
  for _ in $(seq "${TIMEOUT}"); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "${cid}")"
    [ "${status}" = "healthy" ] && return 0
    [ "$(docker inspect -f '{{.State.Running}}' "${cid}")" = "true" ] || break
    sleep 1
  done
  echo "health status: ${status:-none}"
  docker logs --tail 20 "${cid}" 2>&1
  return 1
}

common_checks() {
  local image="$1"
  check "config user is appuser" \
    test "$(docker image inspect -f '{{.Config.User}}' "${image}")" = "appuser"
  check "runs as uid 10001" \
    test "$(run --entrypoint id "${image}" -u)" = "10001"
  # Scan as unrestricted root: with capabilities dropped root can't enter the
  # 0750 appuser dirs, and an unreadable dir would hide a setuid file.
  check "no setuid/setgid binaries" \
    test -z "$(docker run --rm --user 0 -w / --entrypoint find "${image}" / -xdev -type f -perm /6000)"
  check "no build-script mount stub" \
    run --entrypoint sh "${image}" -c '! test -e /opt/golden-scripts'
}

for image in "$@"; do
  repo="${image##*/}"; repo="${repo%%:*}"; repo="${repo%%@*}"
  echo -e "${YELLOW}=== smoke: ${image} ===${NC}"
  common_checks "${image}"

  case "${repo}" in
    nginx-platform)
      # Read-only root filesystem: nginx only needs a writable /tmp.
      cid="$(start "${image}" --read-only --tmpfs /tmp:rw,noexec,nosuid)"
      check "HEALTHCHECK turns healthy (read-only rootfs)" healthy "${cid}"
      check "/health returns 'healthy'" \
        sh -c "docker exec ${cid} wget -q -O - http://127.0.0.1:8080/health | grep -qx healthy"
      check "security headers are sent" \
        sh -c "docker exec ${cid} wget -q -S -O /dev/null http://127.0.0.1:8080/health 2>&1 | grep -qi 'X-Content-Type-Options: nosniff'"
      check "server version is hidden" \
        sh -c "! docker exec ${cid} wget -q -S -O /dev/null http://127.0.0.1:8080/health 2>&1 | grep -qiE 'Server: nginx/[0-9]'"
      ;;
    tomcat-platform)
      cid="$(start "${image}")"
      check "HEALTHCHECK turns healthy (connector answers HTTP)" healthy "${cid}"
      check "no default webapps deployed" \
        run --entrypoint sh "${image}" -c 'test -z "$(ls -A /opt/tomcat/webapps)"'
      check "install is read-only to appuser" \
        run --entrypoint sh "${image}" -c '! touch /opt/tomcat/conf/server.xml 2>/dev/null && ! touch /opt/tomcat/lib/x 2>/dev/null'
      ;;
    python-platform)
      check "stdlib ssl + sqlite3 import" \
        run "${image}" python3 -c 'import ssl, sqlite3, json; print(ssl.OPENSSL_VERSION)'
      check "no pip shipped in the runtime" \
        run "${image}" sh -c '! python3 -m pip --version 2>/dev/null'
      check "ensurepip bootstraps pip into the venv (build-stage pattern)" \
        run "${image}" sh -c 'python3 -m ensurepip >/dev/null && python3 -m pip --version | grep -q /opt/venv'
      cid="$(start "${image}" -- sleep 300)"
      check "HEALTHCHECK turns healthy" healthy "${cid}"
      ;;
    openjdk-platform|springboot-platform)
      check "JRE starts" run "${image}" java -version
      check "JAVA_HOME resolves" run "${image}" sh -c 'test -x "${JAVA_HOME}/bin/java"'
      cid="$(start "${image}" -- sleep 300)"
      check "HEALTHCHECK turns healthy" healthy "${cid}"
      ;;
    aspnet-platform|dotnet-platform)
      want="Microsoft.NETCore.App"; [ "${repo}" = "aspnet-platform" ] && want="Microsoft.AspNetCore.App"
      check "${want} runtime present" sh -c "docker run --rm --cap-drop ALL ${image} dotnet --list-runtimes | grep -q '${want} '"
      check "host starts (dotnet --info)" run "${image}" dotnet --info
      cid="$(start "${image}" -- sleep 300)"
      check "HEALTHCHECK turns healthy" healthy "${cid}"
      ;;
    alpine-hardened|debian-hardened|redhat-hardened)
      check "default shell runs" run "${image}" sh -c 'grep -q "^ID=" /etc/os-release'
      check "CA bundle present" run "${image}" sh -c 'test -s /etc/ssl/certs/ca-certificates.crt || test -s /etc/pki/tls/certs/ca-bundle.crt'
      cid="$(start "${image}" -- sleep 300)"
      check "HEALTHCHECK turns healthy" healthy "${cid}"
      ;;
    *)
      echo "  (no runtime-specific checks for ${repo})"
      ;;
  esac
  echo ""
done

if [ "${rc}" -ne 0 ]; then
  echo -e "${RED}Smoke tests FAILED.${NC}" >&2
else
  echo -e "${GREEN}All smoke tests passed.${NC}"
fi
exit "${rc}"
