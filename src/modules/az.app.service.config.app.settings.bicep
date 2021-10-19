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
param appName string

@description('A collection of key valued pair configurations to set for the a specific app')
param appSettings object = {}


resource azAppServiceSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appName}/appsettings', '@environment', environment), '@location', location)
  properties: appSettings
}
