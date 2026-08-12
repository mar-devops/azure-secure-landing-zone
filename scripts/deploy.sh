#!/usr/bin/env bash
# deploy.sh - creates the resource group and deploys main.bicep
#
# Usage: ./scripts/deploy.sh [resource-group-name] [location]
# Defaults: rg-landingzone-basic-demo / germanywestcentral

set -euo pipefail

RG_NAME="${1:-rg-landingzone-basic-demo}"
LOCATION="${2:-germanywestcentral}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Logged in as:"
az account show --query "{user:user.name, subscription:name}" -o table

echo "==> Creating resource group '$RG_NAME' in '$LOCATION' (if it doesn't exist already)"
az group create --name "$RG_NAME" --location "$LOCATION" --output none

echo "==> Validating template (what-if)"
az deployment group what-if \
  --resource-group "$RG_NAME" \
  --template-file "$REPO_ROOT/bicep/main.bicep" \
  --parameters "$REPO_ROOT/bicep/main.parameters.json"

read -p "Proceed with deployment? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Deploying"
az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file "$REPO_ROOT/bicep/main.bicep" \
  --parameters "$REPO_ROOT/bicep/main.parameters.json" \
  --query "properties.outputs"

echo ""
echo "==> Done. Remember: this is billable (App Service B1 + Private Endpoint + Storage)."
echo "    Run ./scripts/destroy.sh $RG_NAME when you're finished with this session."
