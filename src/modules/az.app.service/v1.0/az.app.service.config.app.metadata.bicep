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

@description('The Function App Name to be deployed')
param appServiceName string

@description('Key valued pair object with meta data to attach to an existing app service')
param appServiceMetadata object

resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appServiceName}/metadata', '@environment', environment), '@region', region)
  properties: appServiceMetadata
}

output resource object = azAppServiceSettingsDeployment
