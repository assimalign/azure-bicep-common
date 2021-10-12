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
param keyVaultKeyName string

@allowed([
  'P-256'
  'P-256K'
  'P-384'
  'P-521'
])
@description('')
param keyVaultKeyCurveName string 

@description('')
param keyVaultKeySize int

@description('')
param keyVaultTags object = {}



resource azKeyVaultKeyDeployment 'Microsoft.KeyVault/vaults/keys@2021-04-01-preview' = {
  name: replace(replace('${keyVaultName}/${keyVaultKeyName}', '@environment', environment), '@location', location)
  properties: {
    curveName: keyVaultKeyCurveName
    keySize: keyVaultKeySize
  }
  tags: keyVaultTags
}
