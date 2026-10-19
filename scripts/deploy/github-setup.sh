#!/usr/bin/env bash
# Wire the GitHub repository up for the golden-image pipeline and drive it.
#
# Commands:
#   check                Verify gh auth, the workflow, Actions settings and the
#                        repo variables the pipeline reads.
#   configure [opts]     Store the Azure/ACR identifiers as repository variables
#                        (not secrets: OIDC means nothing secret is stored).
#       --acr-name <n> --client-id <id> --tenant-id <id> --subscription-id <id>
#       --arm64-runner <label|qemu>   override the arm64 runner (optional)
#   run [opts]           Dispatch .github/workflows/build.yml and follow it.
#       --ref <branch>   default: the repo's default branch
#       --no-push        build + gate only
#       --scope <all|base-only|platform-only>
#       --platforms <list>            default: linux/amd64,linux/arm64
#       --latest         also tag the default flavours as latest
#   status               Recent pipeline runs.
# Global: --repo <owner/name> (default: current repo), --dry-run.
#
# Requires: gh (`gh auth login` with repo + workflow scopes), jq.
set -euo pipefail
cd "$(dirname "$0")/../.."

WORKFLOW="build.yml"
CMD="${1:-}"; [ "$#" -gt 0 ] && shift
REPO=""; DRY_RUN=0
ACR=""; CLIENT=""; TENANT=""; SUB=""; ARM_RUNNER=""
REF=""; PUSH=true; SCOPE=all; PLATFORMS="linux/amd64,linux/arm64"; LATEST=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)            REPO="$2"; shift ;;
    --dry-run)         DRY_RUN=1 ;;
    --acr-name)        ACR="$2"; shift ;;
    --client-id)       CLIENT="$2"; shift ;;
    --tenant-id)       TENANT="$2"; shift ;;
    --subscription-id) SUB="$2"; shift ;;
    --arm64-runner)    ARM_RUNNER="$2"; shift ;;
    --ref)             REF="$2"; shift ;;
    --no-push)         PUSH=false ;;
    --scope)           SCOPE="$2"; shift ;;
    --platforms)       PLATFORMS="$2"; shift ;;
    --latest)          LATEST=true ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

die()  { echo "github-setup: $*" >&2; exit 1; }
ok()   { printf '  \033[0;32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
gh_()  { if [ "${DRY_RUN}" -eq 1 ]; then printf '  gh'; printf ' %q' "$@"; printf '\n'; else gh "$@"; fi; }

command -v gh >/dev/null || die "GitHub CLI not found (https://cli.github.com)"
command -v jq >/dev/null || die "jq is required"
[ -n "${REPO}" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

case "${CMD}" in
  check)
    echo "Checking ${REPO}"
    gh auth status >/dev/null 2>&1 && ok "gh authenticated" || die "run: gh auth login"
    DEFAULT_BRANCH="$(gh repo view "${REPO}" --json defaultBranchRef -q .defaultBranchRef.name)"
    ok "default branch: ${DEFAULT_BRANCH}"
    if gh api "repos/${REPO}/contents/.github/workflows/${WORKFLOW}?ref=${DEFAULT_BRANCH}" >/dev/null 2>&1; then
      ok "${WORKFLOW} is on ${DEFAULT_BRANCH}"
    else
      warn "${WORKFLOW} is not on ${DEFAULT_BRANCH} yet — merge it before dispatching"
    fi
    if [ "$(gh api "repos/${REPO}/actions/permissions" -q .enabled)" = "true" ]; then
      ok "GitHub Actions enabled"
    else
      warn "GitHub Actions is disabled for this repo"
    fi
    vars="$(gh variable list --repo "${REPO}" --json name -q '.[].name' 2>/dev/null || true)"
    missing=()
    for v in ACR_NAME AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
      grep -qx "${v}" <<< "${vars}" || missing+=("${v}")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
      ok "Azure variables set — publishing will promote to ACR"
    else
      warn "not set: ${missing[*]} — GHCR only (run scripts/deploy/azure-bootstrap.sh --configure-github)"
    fi
    if grep -qx ARM64_RUNNER <<< "${vars}"; then
      ok "ARM64_RUNNER=$(gh variable get ARM64_RUNNER --repo "${REPO}")"
    elif [ "$(gh repo view "${REPO}" --json visibility -q .visibility)" = "PUBLIC" ]; then
      ok "arm64 builds natively on ubuntu-24.04-arm (free for public repos)"
    else
      warn "private repo: if your plan has no hosted arm64 runners, set ARM64_RUNNER=qemu (or a larger-runner label)"
    fi
    echo "GHCR packages are created private on first push; make them public under"
    echo "  https://github.com/${REPO%%/*}?tab=packages if consumers pull anonymously."
    ;;

  configure)
    [ -n "${ACR}" ] && [ -n "${CLIENT}" ] && [ -n "${TENANT}" ] && [ -n "${SUB}" ] ||
      die "configure needs --acr-name, --client-id, --tenant-id and --subscription-id"
    gh_ variable set ACR_NAME --repo "${REPO}" --body "${ACR}"
    gh_ variable set AZURE_CLIENT_ID --repo "${REPO}" --body "${CLIENT}"
    gh_ variable set AZURE_TENANT_ID --repo "${REPO}" --body "${TENANT}"
    gh_ variable set AZURE_SUBSCRIPTION_ID --repo "${REPO}" --body "${SUB}"
    [ -z "${ARM_RUNNER}" ] || gh_ variable set ARM64_RUNNER --repo "${REPO}" --body "${ARM_RUNNER}"
    # Legacy secrets from the password-based ACR sync are no longer read.
    for s in ACR_USERNAME ACR_PASSWORD ACR_LOGIN_SERVER ACR_REGISTRY; do
      if gh secret list --repo "${REPO}" --json name -q '.[].name' 2>/dev/null | grep -qx "${s}"; then
        warn "secret ${s} is no longer used; remove it with: gh secret delete ${s} --repo ${REPO}"
      fi
    done
    [ "${DRY_RUN}" -eq 1 ] || ok "repository variables set on ${REPO}"
    ;;

  run)
    [ -n "${REF}" ] || REF="$(gh repo view "${REPO}" --json defaultBranchRef -q .defaultBranchRef.name)"
    gh_ workflow run "${WORKFLOW}" --repo "${REPO}" --ref "${REF}" \
      -f push_images="${PUSH}" -f build_scope="${SCOPE}" \
      -f platforms="${PLATFORMS}" -f publish_latest="${LATEST}"
    [ "${DRY_RUN}" -eq 1 ] && exit 0
    sleep 5
    run_id="$(gh run list --repo "${REPO}" --workflow "${WORKFLOW}" --branch "${REF}" \
      --event workflow_dispatch --limit 1 --json databaseId -q '.[0].databaseId')"
    [ -n "${run_id}" ] || die "dispatched, but could not find the run"
    gh run watch "${run_id}" --repo "${REPO}" --exit-status
    ;;

  status)
    gh run list --repo "${REPO}" --workflow "${WORKFLOW}" --limit 10
    ;;

  *)
    sed -n '2,22p' "$0"
    exit 2
    ;;
esac
