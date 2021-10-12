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

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string

// 1. Get the existing Event Grid Resource
resource azEventGridDomainExistingResource 'Microsoft.EventGrid/domains@2020-10-15-preview' existing = {
  name: replace(replace('${resourceName}', '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace('${resourceGroupName}', '@environment', environment), '@location', location))
}

// 2. Create or Update Key Vault Secret with Event Grid Keys
resource azEventGridDomainKeyVaultSecretDeployment 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: replace(replace(keyVaultName, '@environment', environment), '@location', location)
  resource azEventGridDomainPrimaryKeySecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-primary-key'
    properties: {
      value: listKeys(azEventGridDomainExistingResource.id, azEventGridDomainExistingResource.apiVersion).key1
    }
  }
}
