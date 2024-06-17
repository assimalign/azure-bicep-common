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
param peeringLocalVirtualNetwork string

@description('')
param peeringLocalVirtualNetworkConfig object = {}

@description('the name of the remote virtual network')
param peeringRemoteVirtualNetwork string

@description('The name of the resource group the remote virtual network lives in')
param peeringRemoteVirtualNetworkResourceGroup string

func formatId(name string, affix string, environment string, region string) string =>
  guid(replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region))

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource remoteVritualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: formatName(peeringLocalVirtualNetwork, affix, environment, region)
}

resource virtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: formatName(peeringLinkName, affix, environment, region)
  parent: remoteVritualNetwork
  properties: {
    peeringState: 'Initiated'
    allowForwardedTraffic: peeringLocalVirtualNetworkConfig.?allowForwardedTraffic ?? false
    allowVirtualNetworkAccess: peeringLocalVirtualNetworkConfig.?allowVirtualNetworkAccess ?? false
    allowGatewayTransit: peeringLocalVirtualNetworkConfig.?allowGatewayTransit ?? false
    useRemoteGateways: peeringLocalVirtualNetworkConfig.?allowRemoteGatewayUse ?? false
    remoteVirtualNetwork: {
      id: resourceId(
        formatName(peeringRemoteVirtualNetworkResourceGroup, affix, environment, region),
        'Microsoft.Network/virtualNetworks',
        formatName(peeringRemoteVirtualNetwork, affix, environment, region)
      )
    }
  }
}
