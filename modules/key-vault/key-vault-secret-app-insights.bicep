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

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get the existing Document DB Resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing  = {
  name: formatName(resourceName, affix, environment, region)
  scope: resourceGroup(formatName('${resourceGroupName}', affix, environment, region))
}

resource appInsightsKeyVaultSecret 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: formatName(keyVaultName, affix, environment, region)
  resource azAppInsightsConnectionStringSecret 'secrets' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: appInsights.properties.ConnectionString
    }
  }
  resource pppInsightsInstumentationKeySecret 'secrets' = {
    name: '${keyVaultSecretName}-instrumentation-key'
    properties: {
      value: appInsights.properties.ConnectionString
    }
  }
}
