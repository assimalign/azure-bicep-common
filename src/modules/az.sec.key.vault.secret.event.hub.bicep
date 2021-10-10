@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string




resource azEventHubNamespaceExistingResource 'Microsoft.EventHub/namespaces/authorizationRules@2021-01-01-preview' existing = {
  name: replace('${resourceName}', '@environment', environment)
  scope: resourceGroup('${resourceGroupName}')
}
resource azEventHubNamespaceKeyVaultSecretDeployment 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: replace(keyVaultName, '@environment', environment)
  resource azEventHubNamespaceConnectionStringSecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: listKeys(azEventHubNamespaceExistingResource.id, azEventHubNamespaceExistingResource.apiVersion).primaryConnectionString
    }
  }
  resource azEventHubNamespacePrimaryKeySecret 'secrets@2021-04-01-preview' = {
    name:  '${keyVaultSecretName}-primary-key' 
    properties: {
      value: listKeys(azEventHubNamespaceExistingResource.id, azEventHubNamespaceExistingResource.apiVersion).primaryKey 
    }
  }
}
