@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Virtual Network to be deployed')
param virtualNetworkName string

@description('An list of address spaces to inlcude in the virtual network deployment')
param virtualNetworkAddressSpaces array

@description('A list of subnet ranges to include in the virtual network deployment')
param virtualNetworkSubnets array



var networkSubnets = [for subnet in virtualNetworkSubnets: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.range
    privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
    serviceEndpoints: subnet.serviceEndpoints
  }
}]

// 1. Deploy the Virtual Network
resource azVirtualNetworkDeployment 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: replace('${virtualNetworkName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworkAddressSpaces
    }
    subnets: networkSubnets
  }
}
