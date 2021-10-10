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

@description('The name of the app configuration')
param appConfigurationName string

@description('The name of the Key Vaule')
param appConfigurationKeyName string

@secure()
@description('The value of the App configuration to create or update')
param appConfigurationValue string

@description('The content type of the configuration value')
param appConfigurationContentType string = ''

var configKey = replace(replace('${appConfigurationName}/${appConfigurationKeyName}', '@environment', environment), '@location', location)
var configValue = replace(replace(appConfigurationValue, '@environment', environment), '@location', location)

resource azAppConfigurationKeyValuesDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-03-01-preview' = {
  name: configKey
  properties: {
    value: configValue
    contentType: empty(appConfigurationContentType) ? json('null') : appConfigurationContentType
  }
}
