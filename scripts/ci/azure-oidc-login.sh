#!/usr/bin/env bash
# Log the Azure CLI in from GitHub Actions with OIDC workload identity
# federation, then log Docker in to ACR. No client secret or ACR admin
# password exists anywhere: GitHub mints a short-lived token for this exact
# repo + branch, and Entra ID trusts it through the federated credential that
# scripts/deploy/azure-bootstrap.sh created.
#
# Uses the Azure CLI preinstalled on GitHub-hosted runners instead of a
# third-party login action. The job needs `permissions: id-token: write`.
#
# Env: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, ACR_NAME
set -euo pipefail

for v in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID ACR_NAME \
         ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "azure-oidc-login: ${v} is not set (repo variables, or id-token: write missing)" >&2
    exit 1
  fi
done

token="$(curl -fsS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value')"
echo "::add-mask::${token}"

az login --service-principal --username "${AZURE_CLIENT_ID}" --tenant "${AZURE_TENANT_ID}" \
  --federated-token "${token}" --output none
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
az acr login --name "${ACR_NAME}"
