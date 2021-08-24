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


resource azEventGridDomainExistingResource 'Microsoft.EventGrid/domains@2020-10-15-preview' existing = {
  name:replace('${resourceName}', '@environment', environment)
  scope: resourceGroup(replace('${resourceGroupName}', '@environment', environment))
}

resource azEventGridDomainKeyVaultSecretDeployment 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: replace(keyVaultName, '@environment', environment)
  resource azEventGridDomainPrimaryKeySecret 'secrets@2021-04-01-preview' = {
    name: '${keyVaultSecretName}-primary-key' 
    properties: {
      value:  listKeys(azEventGridDomainExistingResource.id, azEventGridDomainExistingResource.apiVersion).key1
    }
  }
}

