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

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('The name of the ASE to deploy')
param appServiceEnvironmentName string

@description('')
param appServiceEnvironmentLocation string = resourceGroup().location

@allowed([
  'ASEV3'
  'ASEV2'
  'ASEV1'
])
@description('The ASE version to be deployed. Default ASEV3')
param appServiceEnvironmentType string = 'ASEV3'

@description('The Virtual Network settings for the ASE')
param appServiceEnvironmentVirtualNetwork object

@description('')
param appServiceEnvironmentConfigs object = {}

// 1. Get the virtual network to attach to the ASE
resource virtualNetworkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: replace(replace('${appServiceEnvironmentVirtualNetwork.virtualNetworkName}/${appServiceEnvironmentVirtualNetwork.virtualNetworkSubnetName}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceEnvironmentVirtualNetwork.virtualNetworkResourceGroup, '@environment', environment), '@region', region))
}

// 2. Begin Deployment of App Service Environment
resource appServiceEnvrionment 'Microsoft.Web/hostingEnvironments@2023-01-01' = {
  name: replace(replace('${appServiceEnvironmentName}', '@environment', environment), '@region', region)
  location: appServiceEnvironmentLocation
  kind: appServiceEnvironmentType
  properties: {
    zoneRedundant: contains(appServiceEnvironmentConfigs, 'isZoneRedundant') ? appServiceEnvironmentConfigs.isZoneRedundant : false
    dedicatedHostCount: contains(appServiceEnvironmentConfigs, 'dedicatedHostCount') ? appServiceEnvironmentConfigs.dedicatedHostCount : 0
    virtualNetwork: {
      id: virtualNetworkSubnet.id
    }
    internalLoadBalancingMode: contains(appServiceEnvironmentConfigs, 'internalLoadBalancingMode') ? appServiceEnvironmentConfigs.internalLoadBalancingMode : 'None'
  }
}

// 4. Return Deployment ouput
output appServiceEnvironment object = appServiceEnvrionment
