#!/usr/bin/env bash
# Creates the pipeline identity (OIDC, no secret) with least-privilege roles
set -euo pipefail          # stop at the first error
export MSYS_NO_PATHCONV=1  # Git Bash fix for /subscriptions/... paths

APP_NAME="sp-gitlab-cicd"
GITLAB_PROJECT="emlykf/azure-terraform-gitlab-cicd"
PROJECT_RG="rg-gitlab-cicd"
STATE_RG="rg-test01-gwc"
STATE_SA="sttest01gwc"

SUB_ID=$(az account show --query id -o tsv)

# 1. App registration + service principal (reuse if they already exist)
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
fi
SP_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || az ad sp create --id "$APP_ID" --query id -o tsv)

# 2. Federated credential: trust only GitLab tokens from this project's main branch
if ! az ad app federated-credential show --id "$APP_ID" --federated-credential-id gitlab-main --output none 2>/dev/null; then
  az ad app federated-credential create --id "$APP_ID" --output none --parameters "{
    \"name\": \"gitlab-main\",
    \"issuer\": \"https://gitlab.com\",
    \"subject\": \"project_path:$GITLAB_PROJECT:ref_type:branch:ref:main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
fi

sleep 30  # give Entra ID time to make the new identity visible to role assignments

# 3. Roles: Contributor on the project RG only + blob access on the state storage only
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/$SUB_ID/resourceGroups/$PROJECT_RG" --output none

az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" --query id -o tsv)" --output none

# 4. Values for the GitLab CI/CD variables
echo "Done. Add these as GitLab CI/CD variables:"
echo "ARM_CLIENT_ID=$APP_ID"
echo "ARM_TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "ARM_SUBSCRIPTION_ID=$SUB_ID"