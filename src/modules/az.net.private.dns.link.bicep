@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Private DNS Zone')
param privateDnsName string

@description('The name of the Virtual Network Link within the Private DNS Zone')
param privateDnsNameVirtualLinkName string

@description('The name of the vnet')
param privateDnsNameVirtualNetwork string

//-------------------------------------------------------------------------//

// 1. Get the Private DNS Zone to attach 
resource azPrivateDnsResource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
 name: privateDnsName
}

// 2. Get Virtual Network to Link to the Private DNS Zone
resource azVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
 name: replace('${privateDnsNameVirtualNetwork}', '@environment', environment)
}

// 3. Deploy Private DNS Zone Virtual Network Link
resource azPrivateNsVirtualNetworkLinkDeployment 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: azPrivateDnsResource
  name: replace('${privateDnsNameVirtualLinkName}', '@environment', environment)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: azVirtualNetworkResource.id
    }
  }
}




