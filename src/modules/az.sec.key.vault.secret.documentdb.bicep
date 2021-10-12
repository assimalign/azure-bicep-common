@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix for the resource name')
param location string = ''

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string

// 1. Get the existing Document DB Resource
resource azDocumentDbAccountExistingResource 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' existing = {
  name: replace(replace('${resourceName}', '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace('${resourceGroupName}', '@environment', environment), '@location', location))
}

// 2. Create or Update Key Vault Secret with Cosmos DB Primary Key & Connection String
resource azDocumentDbAccountKeyVaultSecretDeployment 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: replace(replace(keyVaultName, '@environment', environment), 'location', location)
  resource azDocumentDbConnectionStringSecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: 'AccountEndpoint=https://${azDocumentDbAccountExistingResource.name}.documents.azure.com:443/;AccountKey=${listKeys(azDocumentDbAccountExistingResource.id, azDocumentDbAccountExistingResource.apiVersion).primaryMasterKey}'
    }
  }
  resource azDocumentDbPrimaryKeySecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-primary-key'
    properties: {
      value: listKeys(azDocumentDbAccountExistingResource.id, azDocumentDbAccountExistingResource.apiVersion).primaryMasterKey
    }
  }
}
