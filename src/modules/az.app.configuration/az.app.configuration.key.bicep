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

@description('The name of the app configuration')
param appConfigurationName string

@description('The name of the Key Vaule')
param appConfigurationKeyName string

@secure()
@description('The value of the App configuration to create or update')
param appConfigurationValue string

@description('')
param appConfigurationValueLabels array = []

@description('The content type of the configuration value')
param appConfigurationContentType string = ''

// **************************************************************************************** //
//                      Azure App Configuration Key Deployment                              //
// **************************************************************************************** //

resource azAppConfigurationKeyValuesDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-03-01-preview' = if (empty(appConfigurationValueLabels)) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKeyName}', '@environment', environment), '@location', location)
  properties: {
    value: replace(replace(appConfigurationValue, '@environment', environment), '@location', location)
    contentType: empty(appConfigurationContentType) ? json('null') : appConfigurationContentType
  }
}

// Deploys the same configuration value with different labels
resource azAppConfigurationKeyValuesWithLabelsDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-03-01-preview' = [for label in appConfigurationValueLabels: if (!empty(appConfigurationValueLabels)) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKeyName}$${label}', '@environment', environment), '@location', location)
  properties: {
    value: '${replace(replace(appConfigurationValue, '@environment', environment), '@location', location)}'
    contentType: empty(appConfigurationContentType) ? json('null') : appConfigurationContentType
  }
}]
