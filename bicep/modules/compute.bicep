// compute.bicep
// Linux App Service with a system-assigned managed identity and regional VNet Integration
// into snet-app. VNet Integration is outbound-only: it lets the app reach private resources
// (our storage private endpoint) inside the VNet. It does NOT put the app's public inbound
// endpoint inside the VNet - that would require an App Service Environment, which is a
// different (and much more expensive) product.
//
// Tier note: VNet Integration requires Basic (B1) or above - Free/Shared tiers don't support
// it. B1 is a few cents/hour, which is fine as long as you tear it down after each session
// (see scripts/destroy.sh).

param location string
param namePrefix string
param appSubnetId string
param tags object

var uniqueSuffix = uniqueString(resourceGroup().id)
var appServicePlanName = '${namePrefix}-plan-${uniqueSuffix}'
var appName = '${namePrefix}-app-${uniqueSuffix}'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: appSubnetId
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      // vnetRouteAllEnabled deliberately left at its default (false): only traffic to
      // private IP ranges (like our private endpoint) needs to go through the VNet.
      // Routing ALL outbound traffic through the VNet is a valid choice too, but it's
      // a separate decision (usually paired with a NAT Gateway or firewall) and out of
      // scope for this project.
    }
  }
}

output appPrincipalId string = appService.identity.principalId
output appName string = appService.name
output appDefaultHostName string = appService.properties.defaultHostName
