// locks.bicep
// OPTIONAL, deploy on-demand only - deliberately kept separate from main.bicep.
//
// Exam trap this models: resource locks override RBAC. A CanNotDelete lock blocks deletion
// even for a principal with Owner/Contributor role - RBAC controls *who can act*, the lock
// controls *whether the action is possible at all*, and the lock wins.
//
// Why this is its own file: a CanNotDelete lock on ANY resource inside a resource group
// blocks `az group delete` for the WHOLE group, not just that resource. If this were wired
// into main.bicep, every teardown would first require manually hunting down and removing
// the lock. Keeping it separate means it's deployed only when you want to demo the behavior,
// and scripts/destroy.sh checks for and removes any locks before deleting the resource group
// either way, as a safety net.
//
// Deploy:  az deployment group create --resource-group <rg> --template-file locks.bicep
// Remove:  az lock delete --name demo-cannotdelete --resource-group <rg>

resource demoLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'demo-cannotdelete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Demo lock for AZ-104 portfolio project - remove before tearing down (destroy.sh does this automatically).'
  }
}
