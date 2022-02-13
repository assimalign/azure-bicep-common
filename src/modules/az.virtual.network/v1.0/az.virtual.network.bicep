@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Virtual Network to be deployed')
param virtualNetworkName string

@description('The location/region the ')
param virtualNetworkLocation string = resourceGroup().location

@description('An list of address spaces to inlcude in the virtual network deployment')
param virtualNetworkAddressSpaces array

@description('A list of subnet ranges to include in the virtual network deployment')
param virtualNetworkSubnets array = []

var subnets = [for subnet in virtualNetworkSubnets: {
  name: replace(replace(subnet.subnetName, '@environment', environment), '@region', region)
  properties: {
    addressPrefix: subnet.subnetRange
    privateEndpointNetworkPolicies: subnet.subnetPrivateEndpointNetworkPolicies
    serviceEndpoints: subnet.subnetServiceEndpoints
  }
}]

// 1. Deploy the Virtual Network
resource azVirtualNetworkDeployment 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: replace(replace(virtualNetworkName, '@environment', environment), '@region', region)
  location: virtualNetworkLocation
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworkAddressSpaces
    }
    subnets: subnets
  }
}
