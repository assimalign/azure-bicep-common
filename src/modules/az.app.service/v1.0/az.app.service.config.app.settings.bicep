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

@description('The Function App Name to be deployed')
param appServiceName string

@description('A collection of key valued pair configurations to set for the a specific app')
param appServiceSettings object = {}

resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appServiceName}/appsettings', '@environment', environment), '@region', region)
  properties: appServiceSettings
}

output appServiceSettings object = azAppServiceSettingsDeployment
