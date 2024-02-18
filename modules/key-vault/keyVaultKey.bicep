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
param keyVaultKeyTags object = {}


resource keyVaultKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: replace(replace('${keyVaultName}/${keyVaultKeyName}', '@environment', environment), '@region', region)
  properties: {
    curveName: keyVaultKeyCurveName
    keySize: keyVaultKeySize
  }
  tags: union(keyVaultKeyTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
