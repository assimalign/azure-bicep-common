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

func format(name string, env string, region string) string => replace(replace(name, '@environment', env), '@region', region)

var value = !empty(environment) && contains(appConfigurationValue, environment) ? appConfigurationValue[environment] : appConfigurationValue.default

resource appConfigKeyValues 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (empty(appConfigurationLabels) || contains(appConfigurationLabels, 'default')) {
  name: format('${appConfigurationName}/${appConfigurationKey}', environment, region)
  properties: {
    value: format(value, environment, region)
    contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
  }
}

// Deploys the same configuration value with different labels
resource appConfigKeyValuesWithLabels 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for label in appConfigurationLabels: if (label != 'default' && !empty(appConfigurationLabels)) {
  name: format('${appConfigurationName}/${appConfigurationKey}$${label}', environment, region)
  properties: {
    value: format(value, environment, region)
    contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
  }
}]
