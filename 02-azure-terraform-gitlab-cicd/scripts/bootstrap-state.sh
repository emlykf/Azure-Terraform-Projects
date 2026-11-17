#!/usr/bin/env bash
# Creates the Terraform state backend (run once, before terraform init)
set -euo pipefail          # stop at the first error
export MSYS_NO_PATHCONV=1  # Git Bash fix for /subscriptions/... paths

RG="rg-test01-gwc"
SA="sttest01gwc"

# Resource group for the Terraform state storage
az group create --name "$RG" --location germanywestcentral --output none

# Project resource group (empty for now; the pipeline creates the VNet, NIC and VM in it)
az group create --name "rg-gitlab-cicd" --location germanywestcentral --output none

az storage account create --name "$SA" --resource-group "$RG" --location germanywestcentral \
  --sku Standard_LRS --kind StorageV2 --https-only true --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false --output none

az storage account blob-service-properties update --account-name "$SA" --resource-group "$RG" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 7 --output none

az role assignment create --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)" --output none

sleep 120  # give the new role time to apply

az storage container create --name tfstate --account-name "$SA" --auth-mode login --output none

echo "Done. State backend is ready."