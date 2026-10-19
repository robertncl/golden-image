#!/usr/bin/env bash
# One-time Azure setup so GitHub Actions can publish golden images to Azure
# Container Registry with NO stored secret.
#
# Idempotent — safe to re-run. It creates (or reuses):
#   1. a resource group and an ACR (admin user disabled: tokens only)
#   2. an Entra ID app registration + service principal for CI
#   3. a federated credential trusting GitHub's OIDC tokens for exactly
#      repo:<owner>/<repo>:ref:refs/heads/<branch>
#   4. an AcrPush role assignment scoped to that one registry (least privilege)
# and prints the four values the workflow needs. With --configure-github it
# also stores them as repository variables via scripts/deploy/github-setup.sh.
#
# Usage:
#   scripts/deploy/azure-bootstrap.sh --acr-name <name> [options]
# Options:
#   --acr-name <name>       Registry name (globally unique, 5-50 alphanumerics). Required.
#   --resource-group <rg>   Default: rg-golden-image
#   --location <region>     Default: westeurope
#   --sku <sku>             Basic | Standard | Premium. Default: Standard
#   --github-repo <o/r>     Default: from the git remote
#   --branch <name>         Branch allowed to publish. Default: the repo's default branch
#   --app-name <name>       Entra app display name. Default: github-<repo>-publisher
#   --configure-github      Also set the GitHub repo variables (needs gh auth).
#   --dry-run               Print the az commands instead of running them.
#
# Requires: az (logged in: `az login`), jq; gh for --configure-github.
set -euo pipefail
cd "$(dirname "$0")/../.."

ACR_NAME=""; RG="rg-golden-image"; LOCATION="westeurope"; SKU="Standard"
REPO=""; BRANCH=""; APP_NAME=""; CONFIGURE_GH=0; DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --acr-name)         ACR_NAME="$2"; shift ;;
    --resource-group)   RG="$2"; shift ;;
    --location)         LOCATION="$2"; shift ;;
    --sku)              SKU="$2"; shift ;;
    --github-repo)      REPO="$2"; shift ;;
    --branch)           BRANCH="$2"; shift ;;
    --app-name)         APP_NAME="$2"; shift ;;
    --configure-github) CONFIGURE_GH=1 ;;
    --dry-run)          DRY_RUN=1 ;;
    -h|--help)          sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "azure-bootstrap: $*" >&2; exit 1; }
step() { printf '\033[0;34m▶ %s\033[0m\n' "$*"; }

[[ "${ACR_NAME}" =~ ^[a-zA-Z0-9]{5,50}$ ]] || die "--acr-name must be 5-50 alphanumeric characters"
command -v jq >/dev/null || die "jq is required"
if [ "${DRY_RUN}" -eq 0 ]; then
  command -v az >/dev/null || die "Azure CLI not found (https://aka.ms/azure-cli)"
fi

if [ -z "${REPO}" ]; then
  REPO="$(git remote get-url origin | sed -E 's#(git@|https://)github.com[:/]##; s#\.git$##')"
fi
[[ "${REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "cannot parse GitHub repo '${REPO}'; pass --github-repo owner/repo"
if [ -z "${BRANCH}" ]; then
  BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  BRANCH="${BRANCH:-master}"
fi
APP_NAME="${APP_NAME:-github-${REPO#*/}-publisher}"
SUBJECT="repo:${REPO}:ref:refs/heads/${BRANCH}"

# az wrapper: in dry-run mode print the command (to stderr, so it shows even
# where the output is captured or discarded) instead of running it.
az_() {
  if [ "${DRY_RUN}" -eq 1 ]; then
    { printf '  az'; printf ' %q' "$@"; printf '\n'; } >&2
  else
    az "$@"
  fi
}

if [ "${DRY_RUN}" -eq 1 ]; then
  echo "(dry run — nothing is created)"
  SUB_ID="<subscription-id>"; TENANT_ID="<tenant-id>"
else
  az account show >/dev/null 2>&1 || die "not logged in — run: az login"
  SUB_ID="$(az account show --query id -o tsv)"
  TENANT_ID="$(az account show --query tenantId -o tsv)"
fi
echo "Subscription: ${SUB_ID}  Tenant: ${TENANT_ID}"
echo "Repo: ${REPO}  Branch: ${BRANCH}  OIDC subject: ${SUBJECT}"

step "Resource group ${RG} (${LOCATION})"
az_ group create --name "${RG}" --location "${LOCATION}" --output none >/dev/null

step "Container registry ${ACR_NAME} (${SKU}, admin user disabled)"
if [ "${DRY_RUN}" -eq 0 ] && az acr show --name "${ACR_NAME}" --resource-group "${RG}" >/dev/null 2>&1; then
  echo "  exists — enforcing admin user disabled"
  az acr update --name "${ACR_NAME}" --admin-enabled false --output none
else
  az_ acr create --name "${ACR_NAME}" --resource-group "${RG}" --location "${LOCATION}" \
    --sku "${SKU}" --admin-enabled false --output none >/dev/null
fi
if [ "${DRY_RUN}" -eq 1 ]; then
  ACR_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"
else
  ACR_ID="$(az acr show --name "${ACR_NAME}" --resource-group "${RG}" --query id -o tsv)"
fi

step "Entra app + service principal ${APP_NAME}"
APP_ID=""
if [ "${DRY_RUN}" -eq 0 ]; then
  APP_ID="$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)"
fi
if [ -z "${APP_ID}" ]; then
  APP_ID="$(az_ ad app create --display-name "${APP_NAME}" --sign-in-audience AzureADMyOrg \
    --query appId -o tsv)"
  [ "${DRY_RUN}" -eq 1 ] && APP_ID="<client-id>"
else
  echo "  exists (${APP_ID})"
fi
if [ "${DRY_RUN}" -eq 1 ] || ! az ad sp show --id "${APP_ID}" >/dev/null 2>&1; then
  az_ ad sp create --id "${APP_ID}" --output none >/dev/null
fi

step "Federated credential for ${SUBJECT}"
CRED_NAME="github-${BRANCH//[^A-Za-z0-9-]/-}"
EXISTING=""
if [ "${DRY_RUN}" -eq 0 ]; then
  EXISTING="$(az ad app federated-credential list --id "${APP_ID}" \
    --query "[?subject=='${SUBJECT}'].name | [0]" -o tsv)"
fi
if [ -z "${EXISTING}" ]; then
  PARAMS="$(jq -cn --arg n "${CRED_NAME}" --arg s "${SUBJECT}" '{
    name: $n, issuer: "https://token.actions.githubusercontent.com", subject: $s,
    description: "GitHub Actions golden-image publishing", audiences: ["api://AzureADTokenExchange"]}')"
  az_ ad app federated-credential create --id "${APP_ID}" --parameters "${PARAMS}" --output none >/dev/null
else
  echo "  exists (${EXISTING})"
fi

step "AcrPush on ${ACR_NAME} only"
if [ "${DRY_RUN}" -eq 1 ] || [ -z "$(az role assignment list --assignee "${APP_ID}" --scope "${ACR_ID}" \
     --role AcrPush --query '[0].id' -o tsv)" ]; then
  # A brand-new service principal can take a few seconds to replicate.
  for attempt in 1 2 3 4 5; do
    if az_ role assignment create --assignee "${APP_ID}" --role AcrPush --scope "${ACR_ID}" \
         --output none; then
      break
    fi
    [ "${attempt}" -eq 5 ] && die "role assignment failed — re-run in a minute"
    sleep 10
  done
else
  echo "  exists"
fi

cat <<EOF

✅ Azure is ready. GitHub repository variables for ${REPO}:
   ACR_NAME=${ACR_NAME}
   AZURE_CLIENT_ID=${APP_ID}
   AZURE_TENANT_ID=${TENANT_ID}
   AZURE_SUBSCRIPTION_ID=${SUB_ID}
These are identifiers, not secrets: the federated credential only accepts
GitHub-issued tokens for ${SUBJECT}.
EOF

if [ "${CONFIGURE_GH}" -eq 1 ]; then
  step "Setting GitHub repository variables"
  args=(configure --repo "${REPO}" --acr-name "${ACR_NAME}" --client-id "${APP_ID}"
        --tenant-id "${TENANT_ID}" --subscription-id "${SUB_ID}")
  [ "${DRY_RUN}" -eq 1 ] && args+=(--dry-run)
  scripts/deploy/github-setup.sh "${args[@]}"
else
  echo "Next: scripts/deploy/github-setup.sh configure --acr-name ${ACR_NAME} --client-id ${APP_ID} --tenant-id ${TENANT_ID} --subscription-id ${SUB_ID}"
fi
