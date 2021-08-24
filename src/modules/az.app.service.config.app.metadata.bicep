

@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The Function App Name to be deployed')
param appName string

@description('Key valued pair object with meta data to attach to an existing app service')
param appMetadata object 




resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace('${appName}/metadata', '@environment', environment) 
  properties: appMetadata
}
