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

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('')
param natGatewayName string

@description('')
param natGatewayResourceLocation string = resourceGroup().location

@description('')
param natGatewayPublicIpAddresses array

@description('')
param natGatewayPublicIpPrefixes array = []

@description('')
param natGatewayTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: formatName(natGatewayName, affix, environment, region)
  sku: {
    name: 'Standard'
  }
  location: natGatewayResourceLocation
  properties: {
    publicIpPrefixes: [
      for prefix in natGatewayPublicIpPrefixes: {
        id: resourceId(
          formatName(prefix.publicIpPrefixResourceGroup, affix, environment, region),
          'Microsoft.Network/publicIPPrefixes',
          formatName(prefix.publicIpPrefixName, affix, environment, region)
        )
      }
    ]
    publicIpAddresses: [
      for ip in natGatewayPublicIpAddresses: {
        id: resourceId(
          formatName(ip.publicIpResourceGroup, affix, environment, region),
          'Microsoft.Network/publicIPAddresses',
          formatName(ip.publicIpName, affix, environment, region)
        )
      }
    ]
  }
  tags: union(natGatewayTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output natGateway object = natGateway
