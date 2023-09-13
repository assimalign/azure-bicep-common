@allowed([
  ''
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
param gatewayName string

@description('')
param gatewayPublicIpAddresses array

@description('')
param gatewayPublicIpPrefixes array

@description('')
param gatewayTags object = {}

var publicIpAddresses = [for ip in gatewayPublicIpAddresses: {
  id: replace(replace(resourceId(ip.resourceGroup, 'Microsoft.Network/publicIPAddresses', ip.name), '@environment', environment), '@region', region)
}]

var publicIpPrefixes = [for prefix in gatewayPublicIpPrefixes: {
  id: replace(replace(resourceId(prefix.resourceGroup, 'Microsoft.Network/publicIPPrefixes', prefix.name), '@environment', environment), '@region', region)
}]

resource azNatGatewayDeployment 'Microsoft.Network/natGateways@2023-05-01' = {
  name: replace(replace('${gatewayName}', '@environment', environment), '@region', region)
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpPrefixes: publicIpPrefixes
    publicIpAddresses: publicIpAddresses
  }
  tags: union(gatewayTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output azNatGateway object = azNatGatewayDeployment
