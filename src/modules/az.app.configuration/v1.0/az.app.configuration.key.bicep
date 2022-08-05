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

@secure()
@description('The value of the App configuration to create or update')
param appConfigurationValue string

@description('Labels to append to App Configuration Key')
param appConfigurationLabels array = []

@description('The content type of the configuration value')
param appConfigurationContentType string = ''

@description('')
param appConfigurationValueEnvReplacements object = {}

// if empty then yes (env agnostic config value) or 
var appConfigReplacements = !empty(appConfigurationValueEnvReplacements) ? appConfigurationValueEnvReplacements : {
  dev: []
  qa: []
  uat: []
  prd: []
}
var appConfig = environment == 'dev' ? {
  value: format(appConfigurationValue, appConfigReplacements.dev)
} : environment == 'qa' ? {
  value: format(appConfigurationValue, appConfigReplacements.qa) 
} : environment == 'uat' ? {
  value: format(appConfigurationValue, appConfigReplacements.uat)
} : environment == 'prd' ? {
  value: format(appConfigurationValue, appConfigReplacements.dev)
} : {
  value: appConfigurationValue
}

resource azAppConfigurationKeyValuesDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = if (empty(appConfigurationLabels) || contains(appConfigurationLabels, 'default')) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKey}', '@environment', environment), '@region', region)
  properties: {
    value: replace(replace(appConfig.value, '@environment', environment), '@region', region)
    contentType: empty(appConfigurationContentType) ? json('null') : appConfigurationContentType
  }
}

// Deploys the same configuration value with different labels
resource azAppConfigurationKeyValuesWithLabelsDeployment 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = [for label in appConfigurationLabels: if (label != 'default' && !empty(appConfigurationLabels)) {
  name: replace(replace('${appConfigurationName}/${appConfigurationKey}$${label}', '@environment', environment), '@region', region)
  properties: {
    value: replace(replace(appConfig.value, '@environment', environment), '@region', region)
    contentType: empty(appConfigurationContentType) ? json('null') : appConfigurationContentType
  }
}]



//Publish-AzBicepModule -FilePath './src/modules/az.app.configuration/v1.0/az.app.configuration.key.bicep' -Target 'br:es2acrdevbicep.azurecr.io/modules/az.app.configuration:v1.0'
