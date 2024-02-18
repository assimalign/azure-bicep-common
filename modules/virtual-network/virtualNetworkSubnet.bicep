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

@description('The name of the subnet to be created under the given virtual network.')
param virtualNetworkSubnetName string

@description('The address range for this subnet within the given address space.')
param virtualNetworkSubnetRange object

@description('')
param virtualNetworkSubnetConfigs object = {}

var properties = {
  addressPrefix: contains(virtualNetworkSubnetRange, environment) ? virtualNetworkSubnetRange[environment] : virtualNetworkSubnetRange.default
  privateEndpointNetworkPolicies: contains(virtualNetworkSubnetConfigs, 'subnetPrivateEndpointNetworkPolicies') ? virtualNetworkSubnetConfigs.subnetPrivateEndpointNetworkPolicies : 'Disabled'
  serviceEndpoints: contains(virtualNetworkSubnetConfigs, 'subnetServiceEndpoints') ? virtualNetworkSubnetConfigs.subnetServiceEndpoints : []
  networkSecurityGroup: contains(virtualNetworkSubnetConfigs, 'subnetNetworkSecurityGroup') ? {
    id: azNetworkSecurityGroup.id
  } : null
  natGateway: contains(virtualNetworkSubnetConfigs, 'subnetNatGateway') ? {
    id: replace(replace(resourceId(virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayResourceGroup, 'Microsoft.Network/natGateways', virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayName), '@environment', environment), '@region', region)
  } : null
  delegations: contains(virtualNetworkSubnetConfigs, 'subnetDelegation') ? [
    {
      name: toLower(replace(virtualNetworkSubnetConfigs.subnetDelegation, '/', '.'))
      properties: {
        serviceName: virtualNetworkSubnetConfigs.subnetDelegation
      }
    }
  ] : null
}

resource azNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-03-01' existing = if (contains(virtualNetworkSubnetConfigs, 'subnetNetworkSecurityGroup')) {
  name: replace(replace(virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgResourceGroup, '@environment', environment), '@region', region))
}

resource azVirtualNetworkSubnetDeployment 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' = {
  name: replace(replace('${virtualNetworkName}/${virtualNetworkSubnetName}', '@environment', environment), '@region', region)
  properties: properties
}


output virtualNetworkSubnet object = azVirtualNetworkSubnetDeployment
