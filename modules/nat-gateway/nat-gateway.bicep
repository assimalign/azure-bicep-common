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

var publicIpAddresses = [for ip in natGatewayPublicIpAddresses: {
  id: replace(replace(resourceId(ip.publicIpResourceGroup, 'Microsoft.Network/publicIPAddresses', ip.publicIpName), '@environment', environment), '@region', region)
}]

var publicIpPrefixes = [for prefix in natGatewayPublicIpPrefixes: {
  id: replace(replace(resourceId(prefix.publicIpPrefixResourceGroup, 'Microsoft.Network/publicIPPrefixes', prefix.publicIpPrefixName), '@environment', environment), '@region', region)
}]

resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: replace(replace(natGatewayName, '@environment', environment), '@region', region)
  sku: {
    name: 'Standard'
  }
  location: natGatewayResourceLocation
  properties: {
    publicIpPrefixes: publicIpPrefixes
    publicIpAddresses: publicIpAddresses
  }
  tags: union(natGatewayTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output natGateway object = natGateway
