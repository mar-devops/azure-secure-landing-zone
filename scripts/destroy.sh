#!/usr/bin/env bash
# destroy.sh - tears the whole demo down.
#
# A CanNotDelete lock on ANY resource in the group blocks deletion of the WHOLE group
# (see bicep/locks.bicep). If you deployed the optional lock demo, this script finds and
# removes it automatically before deleting the resource group - so you never end up with a
# resource group you can't tear down, and no billable resources left running by accident.
#
# Usage: ./scripts/destroy.sh [resource-group-name]
# Default: rg-landingzone-basic-demo

set -euo pipefail

RG_NAME="${1:-rg-landingzone-basic-demo}"

if ! az group show --name "$RG_NAME" &>/dev/null; then
  echo "Resource group '$RG_NAME' doesn't exist (or isn't visible with the current login). Nothing to do."
  exit 0
fi

echo "==> Checking for resource locks in '$RG_NAME'"
LOCK_IDS=$(az lock list --resource-group "$RG_NAME" --query "[].id" -o tsv)

if [[ -n "$LOCK_IDS" ]]; then
  echo "Found lock(s), removing before delete:"
  while IFS= read -r LOCK_ID; do
    echo "  - $LOCK_ID"
    az lock delete --ids "$LOCK_ID"
  done <<< "$LOCK_IDS"
else
  echo "No locks found."
fi

echo "==> Deleting resource group '$RG_NAME' (this blocks until it's actually gone - takes a few minutes)"
az group delete --name "$RG_NAME" --yes

echo "==> Done. '$RG_NAME' is deleted - nothing left running or billing."
