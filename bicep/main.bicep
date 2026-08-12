// main.bicep
// Entry point - deploy at resource group scope:
//   az deployment group create --resource-group <rg> --template-file main.bicep --parameters main.parameters.json
//
// Deploys, in order: network (VNet/subnets/NSGs) -> storage (private storage account
// + private endpoint) -> compute (App Service with VNet Integration) -> rbac (data-plane
// role assignment for the app's managed identity on the storage account).
// Bicep resolves this order automatically from the module output/input dependencies below -
// no explicit dependsOn needed.

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short prefix used to build resource names (lowercase letters/numbers only, keep it short - storage account names have a 24 char limit).')
@minLength(2)
@maxLength(8)
param namePrefix string = 'lzbasic'

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address space for the delegated App Service subnet.')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Address space for the private endpoint subnet.')
param dataSubnetPrefix string = '10.0.2.0/24'

@description('Tags applied to every resource - useful for cost tracking and for demonstrating tag-based governance.')
param tags object = {
  project: 'azure-secure-landingzone-basic'
  purpose: 'portfolio'
  environment: 'demo'
}

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    vnetName: '${namePrefix}-vnet'
    addressPrefix: vnetAddressPrefix
    appSubnetName: 'snet-app'
    appSubnetPrefix: appSubnetPrefix
    dataSubnetName: 'snet-data'
    dataSubnetPrefix: dataSubnetPrefix
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    namePrefix: 'st${namePrefix}'
    vnetId: network.outputs.vnetId
    vnetName: network.outputs.vnetName
    dataSubnetId: network.outputs.dataSubnetId
    tags: tags
  }
}

module compute 'modules/compute.bicep' = {
  name: 'deploy-compute'
  params: {
    location: location
    namePrefix: namePrefix
    appSubnetId: network.outputs.appSubnetId
    tags: tags
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'deploy-rbac'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    principalId: compute.outputs.appPrincipalId
  }
}

output appName string = compute.outputs.appName
output appUrl string = 'https://${compute.outputs.appDefaultHostName}'
output storageAccountName string = storage.outputs.storageAccountName
output vnetName string = network.outputs.vnetName
