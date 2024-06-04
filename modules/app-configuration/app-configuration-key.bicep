@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, prefix string, environment string, region string) string =>
  replace(replace(replace(name, '@prefix', prefix), '@environment', environment), '@region', region)

var value = !empty(environment) && contains(appConfigurationValue, environment)
  ? appConfigurationValue[environment]
  : appConfigurationValue.default

resource appConfigKeyValues 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (empty(appConfigurationLabels) || contains(
  appConfigurationLabels,
  'default'
)) {
  name: formatName('${appConfigurationName}/${appConfigurationKey}', affix, environment, region)
  properties: {
    value: formatName(value, affix, environment, region)
    contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
  }
}

// Deploys the same configuration value with different labels
resource appConfigKeyValuesWithLabels 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [
  for label in appConfigurationLabels: if (label != 'default' && !empty(appConfigurationLabels)) {
    name: formatName('${appConfigurationName}/${appConfigurationKey}$${label}', affix, environment, region)
    properties: {
      value: formatName(value, affix, environment, region)
      contentType: empty(appConfigurationContentType) ? null : appConfigurationContentType
    }
  }
]
