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

@description('The name of the azure Data Factory to be deployed.')
param dataFactoryName string

@description('The location/region the Azure App Service will be deployed to. ')
param dataFactoryLocation string = resourceGroup().location

@description('Enables System Managed Identity for this resource')
param dataFactoryEnableMsi bool = false

@allowed([
  'Allow'
  'Deny'
])
@description('The default action when no rule from ipRules and from virtualNetworkRules match. This is only used after the bypass property has been evaluated.')
param dataFactoryDefaultNetworkAccess string = 'Allow'

@description('The source control to be used for data factory packages.')
param dataFactoryRepositorySettings object = {}

resource azDataFactoryDeployment 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: replace(replace(dataFactoryName, '@environment', environment), '@region', region)
  location: dataFactoryLocation
  identity: any(dataFactoryEnableMsi == true ? {
    type: 'SystemAssigned'
  } : json('null'))
  properties: {
    publicNetworkAccess: dataFactoryDefaultNetworkAccess == 'Allow' ? 'Enabled' : 'Disabled'
    repoConfiguration: any(!empty(dataFactoryRepositorySettings) ? dataFactoryRepositorySettings : {})
  }
}
