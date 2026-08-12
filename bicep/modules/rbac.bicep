// rbac.bicep
// Assigns "Storage Blob Data Contributor" to the App Service's managed identity, scoped to
// the storage account.
//
// Exam trap this models: control-plane vs. data-plane RBAC on storage.
//   - Storage Account Contributor (17d1049b-9a84-46fb-8f53-869881c3d3ab) grants management
//     operations on the storage account itself (view/regenerate keys, configure networking,
//     etc.) but grants NO permission to read or write blobs, queues, tables, or files.
//   - Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe) is the data-plane
//     role: read/write/delete blob data via Entra ID auth, no shared key needed.
//
// An app that needs to actually read/write blobs needs the SECOND role. Assigning
// Storage Account Contributor here is the single most common AZ-104 RBAC mistake -
// it looks right (it has "Storage Account" in the name) and the app will still fail with
// 403 on every blob operation.

param storageAccountName string
param principalId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource blobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
