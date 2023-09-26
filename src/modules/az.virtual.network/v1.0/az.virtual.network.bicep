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
param virtualNetworkAddressSpaces object

@description('A list of subnet ranges to include in the virtual network deployment')
param virtualNetworkSubnets array = []

@description('')
param virtualNetworkConfigs object = {}

@description('')
param virtualNetworkTags object = {}

var subnets = [for subnet in virtualNetworkSubnets: {
  name: replace(replace(subnet.virtualNetworkSubnetName, '@environment', environment), '@region', region)
  properties: {
    addressPrefix: contains(subnet.virtualNetworkSubnetRange, region) ? contains(subnet.virtualNetworkSubnetRange[region], environment) ? subnet.virtualNetworkSubnetRange[region][environment] : subnet.virtualNetworkSubnetRange[region].default : contains(subnet.virtualNetworkSubnetRange, environment) ? subnet.virtualNetworkSubnetRange[environment] : subnet.virtualNetworkSubnetRange.default
    serviceEndpoints: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(subnet.virtualNetworkSubnetConfigs, 'subnetServiceEndpoints') ? subnet.virtualNetworkSubnetConfigs.subnetServiceEndpoints : []
    networkSecurityGroup: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(subnet.virtualNetworkSubnetConfigs, 'subnetNetworkSecurityGroup') ? {
      privateEndpointNetworkPolicies: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(subnet.virtualNetworkSubnetConfigs, 'subnetPrivateEndpointNetworkPolicies') ? subnet.virtualNetworkSubnetConfigs.subnetPrivateEndpointNetworkPolicies : 'Disabled'
      id: resourceId(replace(replace(subnet.virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgResourceGroup, '@environment', environment), '@region', region), 'Microsoft.Network/networkSecurityGroups', replace(replace(subnet.virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgName, '@environment', environment), '@region', region))
    } : null
    natGateway: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(subnet.virtualNetworkSubnetConfigs, 'subnetNatGateway') ? {
      id: replace(replace(resourceId(subnet.virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayResourceGroup, 'Microsoft.Network/natGateways', subnet.virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayName), '@environment', environment), '@region', region)
    } : null
    delegations: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(subnet.virtualNetworkSubnetConfigs, 'subnetDelegation') ? [
      {
        name: toLower(replace(subnet.virtualNetworkSubnetConfigs.subnetDelegation, '/', '.'))
        properties: {
          serviceName: subnet.virtualNetworkSubnetConfigs.subnetDelegation
        }
      }
    ] : null
  }
}]

// 1. Deploy the Virtual Network
resource azVirtualNetworkDeployment 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: replace(replace(virtualNetworkName, '@environment', environment), '@region', region)
  location: virtualNetworkLocation
  properties: {
    addressSpace: {
      addressPrefixes: contains(virtualNetworkAddressSpaces, region) ? contains(virtualNetworkAddressSpaces[region], environment) ? virtualNetworkAddressSpaces[region][environment] : virtualNetworkAddressSpaces[region].default :  contains(virtualNetworkAddressSpaces, environment) ? virtualNetworkAddressSpaces[environment] : virtualNetworkAddressSpaces.default
    }
    subnets: subnets
    enableDdosProtection: contains(virtualNetworkConfigs, 'enableDdosProtection') ? virtualNetworkConfigs.enableDdosProtection : false
    enableVmProtection: contains(virtualNetworkConfigs, 'enableVmProtection') ? virtualNetworkConfigs.enableVmProtection : false
  }
  tags: union(virtualNetworkTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output virtualNetwork object = azVirtualNetworkDeployment
