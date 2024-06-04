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

// 1. Get the existing Service Bus Namespace Authorization Rule Resource
resource serviceBus 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-11-01' existing = {
  name: formatName(resourceName, affix, environment, region)
  scope: resourceGroup(formatName(resourceGroupName, affix, environment, region))
}

// 2. Create or Update Key Vault Secret with Service Bus Namespace Authorization Rule Primary Key & Connection String
resource serviceBusKeyVaultSecret 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: formatName(keyVaultName,  affix, environment, region)
  resource azServiceBusAuthPolicyConnectionStringSecret 'secrets' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: serviceBus.listKeys().primaryConnectionString
    }
  }
  resource serviceBusPrimaryKeySecret 'secrets' = {
    name: '${keyVaultSecretName}-primary-key'
    properties: {
      value:serviceBus.listKeys().primaryKey
    }
  }
}
