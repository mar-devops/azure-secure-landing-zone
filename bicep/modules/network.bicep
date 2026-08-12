// network.bicep
// VNet with two subnets:
//   - snet-app  : delegated to Microsoft.Web/serverFarms, used for App Service regional VNet Integration (outbound)
//   - snet-data : hosts the private endpoint for the storage account
//
// Why two subnets instead of one: the delegation required for App Service VNet Integration
// (Microsoft.Web/serverFarms) is exclusive - a subnet with that delegation can't also host
// a private endpoint. Splitting app/data traffic into separate subnets is also how you'd do
// it in a real environment, since it lets each tier get its own NSG.

param location string
param vnetName string
param addressPrefix string

param appSubnetName string
param appSubnetPrefix string
param dataSubnetName string
param dataSubnetPrefix string

param tags object

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${appSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // Outbound to the data subnet only, on 443 (HTTPS to the storage private endpoint).
        // Everything else outbound falls through to the default AllowInternetOutBound rule,
        // which is intentionally left in place here - locking that down further is a good
        // "next iteration" item, called out in the README.
        name: 'Allow-Outbound-To-Data-Https'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
        }
      }
    ]
  }
}

resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${dataSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // Only the app subnet may reach the private endpoint on 443. Default NSG rules deny
        // all other inbound from outside the VNet, so this is the one explicit allow needed.
        name: 'Allow-Inbound-From-App-Https'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
        }
      }
      {
        // Explicit deny for any other inbound, so the intent is documented rather than
        // relying only on the implicit default deny rule.
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
          delegations: [
            {
              name: 'webapp-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: nsgData.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appSubnetId string = vnet.properties.subnets[0].id
output dataSubnetId string = vnet.properties.subnets[1].id
