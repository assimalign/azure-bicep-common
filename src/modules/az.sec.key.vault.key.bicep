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
param keyVaultKeyName string

@description('')
param keyVaultTags object = {}



resource azKeyVaultKeyDeployment 'Microsoft.KeyVault/vaults/keys@2021-04-01-preview' = {
  name: replace('${keyVaultName}/${keyVaultKeyName}', '@environment', environment)
  properties: {
     
  }
  tags: keyVaultTags
}
