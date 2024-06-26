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

@description('The name of the Virtual Network to be deployed')
param virtualNetworkName string

@description('The name of the subnet to be created under the given virtual network.')
param virtualNetworkSubnetName string

@description('The address range for this subnet within the given address space.')
param virtualNetworkSubnetRange object

@description('')
param virtualNetworkSubnetConfigs object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' existing = if (contains(
  virtualNetworkSubnetConfigs,
  'subnetNetworkSecurityGroup'
)) {
  name: formatName(virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgName, affix, environment, region)
  scope: resourceGroup(formatName(
    virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgResourceGroup,
    affix,
    environment,
    region
  ))
}

resource virtualNetworkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: formatName('${virtualNetworkName}/${virtualNetworkSubnetName}', affix, environment, region)
  properties: {
    addressPrefix: contains(virtualNetworkSubnetRange, environment)
      ? virtualNetworkSubnetRange[environment]
      : virtualNetworkSubnetRange.default
    privateEndpointNetworkPolicies: contains(virtualNetworkSubnetConfigs, 'subnetPrivateEndpointNetworkPolicies')
      ? virtualNetworkSubnetConfigs.subnetPrivateEndpointNetworkPolicies
      : 'Disabled'
    serviceEndpoints: contains(virtualNetworkSubnetConfigs, 'subnetServiceEndpoints')
      ? virtualNetworkSubnetConfigs.subnetServiceEndpoints
      : []
    networkSecurityGroup: contains(virtualNetworkSubnetConfigs, 'subnetNetworkSecurityGroup')
      ? {
          id: networkSecurityGroup.id
        }
      : null
    natGateway: contains(virtualNetworkSubnetConfigs, 'subnetNatGateway')
      ? {
          id: resourceId(
            formatName(virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayResourceGroup, affix, environment, region),
            'Microsoft.Network/natGateways',
            formatName(virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayName, affix, environment, region)
          )
        }
      : null
    delegations: contains(virtualNetworkSubnetConfigs, 'subnetDelegation')
      ? [
          {
            name: toLower(replace(virtualNetworkSubnetConfigs.subnetDelegation, '/', '.'))
            properties: {
              serviceName: virtualNetworkSubnetConfigs.subnetDelegation
            }
          }
        ]
      : null
  }
}

output virtualNetworkSubnet object = virtualNetworkSubnet
