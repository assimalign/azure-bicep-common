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

@description('The name of the DNS Resolver.')
param dnsResolverName string

@description('The deployment location of the DNS Resolver.')
param dnsResolverLocation string = resourceGroup().location

@description('The virtual network to link to the dns resolver.')
param dnsResolverVirtualNetworkName string

@description('')
param dnsResolverVirtualNetworkResourceGroup string = resourceGroup().name

@description('')
param dnsResolverInboundEndpoints array = []

@description('')
param dnsResolverOutboundEndpoints array = []

@description('The tags to attach to the resource when deployed')
param dnsResolverTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: formatName(dnsResolverVirtualNetworkName, affix, environment, region)
  scope: resourceGroup(formatName(dnsResolverVirtualNetworkResourceGroup, affix, environment, region))
}

resource inboundSubnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = [
  for endpoint in dnsResolverInboundEndpoints: {
    name: formatName('${dnsResolverVirtualNetworkName}/${endpoint.endpointSubnetName}', affix, environment, region)
    scope: resourceGroup(formatName(dnsResolverVirtualNetworkResourceGroup, affix, environment, region))
  }
]

resource outboundSubnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = [
  for endpoint in dnsResolverOutboundEndpoints: {
    name: formatName('${dnsResolverVirtualNetworkName}/${endpoint.endpointSubnetName}', affix, environment, region)
    scope: resourceGroup(formatName(dnsResolverVirtualNetworkResourceGroup, affix, environment, region))
  }
]

resource dnsr 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: formatName(dnsResolverName, affix, environment, region)
  location: dnsResolverLocation
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
  tags: union(dnsResolverTags, {
    region: region
    environment: environment
  })
  resource inboundEndpoints 'inboundEndpoints' = [
    for (endpoint, index) in dnsResolverInboundEndpoints: {
      name: formatName(endpoint.endpointName, affix, environment, region)
      location: dnsResolverLocation
      properties: {
        ipConfigurations: [
          {
            privateIpAddress: endpoint.?endpointStaticIp
            privateIpAllocationMethod: contains(endpoint, 'endpointStaticIp') ? 'Static' : 'Dynamic'
            subnet: {
              id: inboundSubnets[index].id
            }
          }
        ]
      }
    }
  ]
  resource outboundEndpoints 'outboundEndpoints' = [
    for (endpoint, index) in dnsResolverOutboundEndpoints: {
      name: formatName(endpoint.endpointName, affix, environment, region)
      location: dnsResolverLocation
      properties: {
        subnet: {
          id: outboundSubnets[index].id
        }
      }
    }
  ]
}

output dnsResolver object = dnsr
