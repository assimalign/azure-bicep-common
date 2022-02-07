@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The Function App Name to be deployed')
param appServiceName string

@description('Key valued pair object with meta data to attach to an existing app service')
param appServiceMetadata object

resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appServiceName}/metadata', '@environment', environment), '@location', location)
  properties: appServiceMetadata
}

output resource object = azAppServiceSettingsDeployment
