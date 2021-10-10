@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('A prefix or suffix identifying the deployment location as part of the naming convention of the resource')
param location string = ''

@description('The Function App Name to be deployed')
param appName string

@description('Key valued pair object with meta data to attach to an existing app service')
param appMetadata object

resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appName}/metadata', '@environment', environment), '@location', location)
  properties: appMetadata
}
