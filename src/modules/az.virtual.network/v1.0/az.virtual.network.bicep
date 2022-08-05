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

@description('The name of the Virtual Network to be deployed')
param virtualNetworkName string

@description('The location/region the ')
param virtualNetworkLocation string = resourceGroup().location

@description('An list of address spaces to inlcude in the virtual network deployment')
param virtualNetworkAddressSpaces array

@description('A list of subnet ranges to include in the virtual network deployment')
param virtualNetworkSubnets array = []

@description('')
param virtualNetworkConfigs object = {}

@description('')
param virtualNetworkTags object = {}

// 1. Deploy the Virtual Network
resource azVirtualNetworkDeployment 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: replace(replace(virtualNetworkName, '@environment', environment), '@region', region)
  location: virtualNetworkLocation
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworkAddressSpaces
    }
    enableDdosProtection: contains(virtualNetworkConfigs, 'enableDdosProtection') ? virtualNetworkConfigs.enableDdosProtection : false
    enableVmProtection: contains(virtualNetworkConfigs, 'enableVmProtection') ? virtualNetworkConfigs.enableVmProtection : false
  }
  tags: union(virtualNetworkTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

module azVirtualNetorkSubnetDeployment './az.virtual.network.subnet.bicep' = [for subnet in virtualNetworkSubnets: if (!empty(virtualNetworkSubnets)) {
  name: !empty(virtualNetworkSubnets) ? toLower('az-vnet-subnet-${guid('${azVirtualNetworkDeployment.id}/${subnet.virtualNetworkSubnetName}')}') : 'no-vnet-subnet-to-deploy'
  params: {
    region: region
    environment: environment
    virtualNetworkName: virtualNetworkName
    virtualNetworkSubnetName: subnet.virtualNetworkSubnetName
    virtualNetworkSubnetRange: subnet.virtualNetworkSubnetRange
    virtualNetworkSubnetConfigs: subnet.virtualNetworkSubnetConfigs
  }
}]

output virtualNetwork object = azVirtualNetworkDeployment
