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

@description('The name of the app configuration')
param appConfigurationName string

@description('The name of the Key Vaule')
param appConfigurationKey string

@description('The value of the App configuration to create or update')
param appConfigurationValue object

@description('Labels to append to App Configuration Key')
param appConfigurationLabels array = []

@description('The content type of the configuration value')
param appConfigurationContentType string = ''

var value = !empty(environment) && contains(appConfigurationValue, environment) ? appConfigurationValue[environment] : appConfigurationValue.default

resource azAppConfigurationKeyValuesDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = if (empty(appConfigurationLabels) || contains(appConfigurationLabels, 'default')) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKey}', '@environment', environment), '@region', region)
  properties: {
    value: replace(replace(value, '@environment', environment), '@region', region)
    contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
  }
}

// Deploys the same configuration value with different labels
resource azAppConfigurationKeyValuesWithLabelsDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = [for label in appConfigurationLabels: if (label != 'default' && !empty(appConfigurationLabels)) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKey}$${label}', '@environment', environment), '@region', region)
  properties: {
    value: replace(replace(value, '@environment', environment), '@region', region)
    contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
  }
}]
