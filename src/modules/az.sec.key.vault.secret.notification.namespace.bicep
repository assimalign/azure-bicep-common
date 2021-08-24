@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string



resource azNotificationNamespaceExistingResource 'Microsoft.NotificationHubs/namespaces/AuthorizationRules@2017-04-01' existing =  {
  name: replace('${resourceName}', '@environment', environment)
  scope: resourceGroup(replace('${resourceGroupName}', '@environment', environment))
}

resource azKeyVaultExistingResource 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing =  {
  name: replace(keyVaultName, '@environment', environment)
  resource azNotificationNamespaceAuthPolicyConnectionStringSecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: listKeys(azNotificationNamespaceExistingResource.id, azNotificationNamespaceExistingResource.apiVersion).primaryConnectionString 
    }
  }
  resource azNotificationNamespaceAuthPolicyPrimaryKeySecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-primary-key'
    properties: {
      value: listKeys(azNotificationNamespaceExistingResource.id, azNotificationNamespaceExistingResource.apiVersion).primaryKey 
    }
  }
}
