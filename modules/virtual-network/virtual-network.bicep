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

@description('The deployment location of the virtual network ')
param virtualNetworkLocation string = resourceGroup().location

@description('An list of address spaces to inlcude in the virtual network deployment')
param virtualNetworkAddressSpaces object

@description('A list of subnet ranges to include in the virtual network deployment')
param virtualNetworkSubnets array = []

@description('')
param virtualNetworkConfigs object = {}

@description('')
param virtualNetworkTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy the Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: formatName(virtualNetworkName, affix, environment, region)
  location: virtualNetworkLocation
  properties: {
    dhcpOptions: contains(virtualNetworkConfigs, 'dnsServers')
      ? {
          dnsServers: contains(virtualNetworkConfigs.dnsServers, affix)
          ? contains(virtualNetworkConfigs.dnsServers[affix], region)
              ? contains(virtualNetworkConfigs.dnsServers[affix][region], environment)
                  ? virtualNetworkConfigs.dnsServers[affix][region][environment]
                  : virtualNetworkConfigs.dnsServers[affix][region].default
              : contains(virtualNetworkConfigs.dnsServers[affix], environment)
                  ? virtualNetworkConfigs.dnsServers[affix][environment]
                  : virtualNetworkConfigs.dnsServers[affix].default
          : contains(virtualNetworkConfigs.dnsServers, region)
              ? contains(virtualNetworkConfigs.dnsServers[region], environment)
                  ? virtualNetworkConfigs.dnsServers[region][environment]
                  : virtualNetworkConfigs.dnsServers[region].default
              : contains(virtualNetworkConfigs.dnsServers, environment)
                  ? virtualNetworkConfigs.dnsServers[environment]
                  : virtualNetworkConfigs.dnsServers.default
        }
      : null
    addressSpace: {
      addressPrefixes: contains(virtualNetworkAddressSpaces, affix)
        ? contains(virtualNetworkAddressSpaces[affix], region)
            ? contains(virtualNetworkAddressSpaces[affix][region], environment)
                ? virtualNetworkAddressSpaces[affix][region][environment]
                : virtualNetworkAddressSpaces[affix][region].default
            : contains(virtualNetworkAddressSpaces[affix], environment)
                ? virtualNetworkAddressSpaces[affix][environment]
                : virtualNetworkAddressSpaces[affix].default
        : contains(virtualNetworkAddressSpaces, region)
            ? contains(virtualNetworkAddressSpaces[region], environment)
                ? virtualNetworkAddressSpaces[region][environment]
                : virtualNetworkAddressSpaces[region].default
            : contains(virtualNetworkAddressSpaces, environment)
                ? virtualNetworkAddressSpaces[environment]
                : virtualNetworkAddressSpaces.default
    }
    subnets: [
      for subnet in virtualNetworkSubnets: {
        name: formatName(subnet.virtualNetworkSubnetName, affix, environment, region)
        properties: {
          addressPrefix: contains(subnet.virtualNetworkSubnetRange, affix)
            ? contains(subnet.virtualNetworkSubnetRange[affix], region)
                ? contains(subnet.virtualNetworkSubnetRange[affix][region], environment)
                    ? subnet.virtualNetworkSubnetRange[affix][region][environment]
                    : subnet.virtualNetworkSubnetRange[affix][region].default
                : contains(subnet.virtualNetworkSubnetRange[affix], environment)
                    ? subnet.virtualNetworkSubnetRange[affix][environment]
                    : subnet.virtualNetworkSubnetRange[affix].default
            : contains(subnet.virtualNetworkSubnetRange, region)
                ? contains(subnet.virtualNetworkSubnetRange[region], environment)
                    ? subnet.virtualNetworkSubnetRange[region][environment]
                    : subnet.virtualNetworkSubnetRange[region].default
                : contains(subnet.virtualNetworkSubnetRange, environment)
                    ? subnet.virtualNetworkSubnetRange[environment]
                    : subnet.virtualNetworkSubnetRange.default
          serviceEndpoints: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(
              subnet.virtualNetworkSubnetConfigs,
              'subnetServiceEndpoints'
            )
            ? subnet.virtualNetworkSubnetConfigs.subnetServiceEndpoints
            : []
          networkSecurityGroup: any(contains(subnet, 'virtualNetworkSubnetConfigs') && contains(
              subnet.virtualNetworkSubnetConfigs,
              'subnetNetworkSecurityGroup'
            )
            ? {
                privateEndpointNetworkPolicies: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(
                    subnet.virtualNetworkSubnetConfigs,
                    'subnetPrivateEndpointNetworkPolicies'
                  )
                  ? subnet.virtualNetworkSubnetConfigs.subnetPrivateEndpointNetworkPolicies
                  : 'Disabled'
                id: resourceId(
                  formatName(
                    subnet.virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgResourceGroup,
                    affix,
                    environment,
                    region
                  ),
                  'Microsoft.Network/networkSecurityGroups',
                  formatName(
                    subnet.virtualNetworkSubnetConfigs.subnetNetworkSecurityGroup.nsgName,
                    affix,
                    environment,
                    region
                  )
                )
              }
            : null)
          natGateway: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(
              subnet.virtualNetworkSubnetConfigs,
              'subnetNatGateway'
            )
            ? {
                id: resourceId(
                  formatName(
                    subnet.virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayResourceGroup,
                    affix,
                    environment,
                    region
                  ),
                  'Microsoft.Network/natGateways',
                  formatName(
                    subnet.virtualNetworkSubnetConfigs.subnetNatGateway.natGatewayName,
                    affix,
                    environment,
                    region
                  )
                )
              }
            : null
          delegations: contains(subnet, 'virtualNetworkSubnetConfigs') && contains(
              subnet.virtualNetworkSubnetConfigs,
              'subnetDelegation'
            )
            ? [
                {
                  name: toLower(replace(subnet.virtualNetworkSubnetConfigs.subnetDelegation, '/', '.'))
                  properties: {
                    serviceName: subnet.virtualNetworkSubnetConfigs.subnetDelegation
                  }
                }
              ]
            : null
        }
      }
    ]
    enableDdosProtection: contains(virtualNetworkConfigs, 'enableDdosProtection')
      ? virtualNetworkConfigs.enableDdosProtection
      : false
    enableVmProtection: contains(virtualNetworkConfigs, 'enableVmProtection')
      ? virtualNetworkConfigs.enableVmProtection
      : false
  }
  tags: union(virtualNetworkTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output virtualNetwork object = virtualNetwork
