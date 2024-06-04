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

@description('The name of the Private DNS Zone')
param privateDnsName string

@description('The name of the Virtual Network Link within the Private DNS Zone')
param privateDnsVirtualLinkName string

@description('The name of the vnet')
param privateDnsVirtualNetworkName string

@description('')
param privateDnsVirtualLinkTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get the Private DNS Zone to attach 
resource azPrivateDnsResource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: formatName(privateDnsName, affix, environment, region)
}

// 2. Get Virtual Network to Link to the Private DNS Zone
resource azVirtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: formatName('${privateDnsVirtualNetworkName}', affix, environment, region)
}

// 3. Deploy Private DNS Zone Virtual Network Link
resource azPrivateNsVirtualNetworkLinkDeployment 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: azPrivateDnsResource
  name: formatName(privateDnsVirtualLinkName, affix, environment, region)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: azVirtualNetworkResource.id
    }
  }
  tags: union(privateDnsVirtualLinkTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
