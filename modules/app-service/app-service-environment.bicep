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

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 2. Begin Deployment of App Service Environment
resource appServiceEnvrionment 'Microsoft.Web/hostingEnvironments@2023-01-01' = {
  name: formatName(appServiceEnvironmentName, affix, environment, region)
  location: appServiceEnvironmentLocation
  kind: appServiceEnvironmentType
  properties: {
    zoneRedundant: appServiceEnvironmentConfigs.?isZoneRedundant
    dedicatedHostCount: appServiceEnvironmentConfigs.?dedicatedHostCount
    internalLoadBalancingMode: appServiceEnvironmentConfigs.?internalLoadBalancingMode
    virtualNetwork: {
      id: resourceId(
        formatName(appServiceEnvironmentVirtualNetwork.virtualNetworkResourceGroup, affix, environment, region),
        'Microsoft.Network/virtualNetworks/subnets',
        formatName(appServiceEnvironmentVirtualNetwork.virtualNetworkName, affix, environment, region),
        formatName(appServiceEnvironmentVirtualNetwork.virtualNetworkSubnetName, affix, environment, region)
      )
    }
  }
}

// 4. Return Deployment ouput
output appServiceEnvironment object = appServiceEnvrionment
