@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the peering virtual network link')
param peeringLinkName string

@description('the name of the peering virtual network')
param peeringVirtualNetwork string

@description('The name of the resource group the peering virtual network lives in')
param peeringVirtualNetworkResourceGroup string = resourceGroup().name

@description('the name of the remote virtual network link')
param remoteLinkName string

@description('the name of the remote virtual network')
param remoteVirtualNetwork string

@description('The name of the resource group the remote virtual network lives in')
param remoteVirtualNetworkResourceGroup string = resourceGroup().name

// 1. Get the existing Remote Virtual Network
resource azRemoteVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: replace(replace(remoteVirtualNetwork, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(remoteVirtualNetworkResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get the Peering Virtual Network
resource azPeeringVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: replace(replace(peeringVirtualNetwork, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(peeringVirtualNetworkResourceGroup, '@environment', environment), '@region', region))
}

// 3. Add the Remote Virtual Network to the peering 
resource azRemoteVirtualNetworkPeeringDeployment 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: replace(replace('${azRemoteVirtualNetworkResource.name}/${remoteLinkName}', '@environment', environment), '@region', region)
  properties: {
    peeringState: 'Connected'
    remoteVirtualNetwork: {
      id: azPeeringVirtualNetworkResource.id
    }
  }
}

resource azVirtualNetworkPeeringDeployment 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: replace(replace('${azPeeringVirtualNetworkResource.name}/${peeringLinkName}', '@environment', environment), '@region', region)
  properties: {
    peeringState: 'Connected'
    remoteVirtualNetwork: {
      id: azRemoteVirtualNetworkResource.id
    }
  }
  dependsOn: [
    azRemoteVirtualNetworkPeeringDeployment
  ]
}
