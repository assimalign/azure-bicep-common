@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get the existing Remote Virtual Network
resource azRemoteVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: formatName(remoteVirtualNetwork, affix, environment, region)
  scope: resourceGroup(formatName(remoteVirtualNetworkResourceGroup, affix, environment, region))
}

// 2. Get the Peering Virtual Network
resource azPeeringVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: formatName(peeringVirtualNetwork, affix, environment, region)
  scope: resourceGroup(formatName(peeringVirtualNetworkResourceGroup, affix, environment, region))
}

// 3. Add the Remote Virtual Network to the peering 
resource azRemoteVirtualNetworkPeeringDeployment 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: formatName('${azRemoteVirtualNetworkResource.name}/${remoteLinkName}', affix, environment, region)
  properties: {
    peeringState: 'Connected'
    remoteVirtualNetwork: {
      id: azPeeringVirtualNetworkResource.id
    }
  }
}

resource azVirtualNetworkPeeringDeployment 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: formatName('${azPeeringVirtualNetworkResource.name}/${peeringLinkName}', affix, environment, region)
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
