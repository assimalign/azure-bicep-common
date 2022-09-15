@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('The name of the API Management resource')
param apimGatewayName string

@description('')
param apimGatewayOpenIdConnectName string

@description('')
param apimGatewayOpenIdConnectClientId object

@secure()
@description('A key vault reference nam ')
param apimGatewayOpenIdConnectClientSecret object

@description('')
param apimGatewayOpenIdConnectMetadataUrl object

var keyVaultName = contains(apimGatewayOpenIdConnectClientSecret, environment) ? apimGatewayOpenIdConnectClientSecret[environment].keyVaultName : apimGatewayOpenIdConnectClientSecret.default.keyVaultName
var keyVaultSecretName = contains(apimGatewayOpenIdConnectClientSecret, environment) ? apimGatewayOpenIdConnectClientSecret[environment].keyVaultSecretName : apimGatewayOpenIdConnectClientSecret.default.keyVaultSecretName
var keyVaultResourceGroup = contains(apimGatewayOpenIdConnectClientSecret, environment) ? apimGatewayOpenIdConnectClientSecret[environment].keyVaultResourceGroup : apimGatewayOpenIdConnectClientSecret.default.keyVaultResourceGroup

resource azKeyVaultReference 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: replace(replace(keyVaultName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(keyVaultResourceGroup, '@environment', environment), '@region', region))
}

module azApimGatewayOpendIDConnectDeployment '../supports/az.apim.openid.connect.provider.secure.bicep' = {
  name: uniqueString(replace(replace('${apimGatewayName}/${apimGatewayOpenIdConnectName}', '@environment', environment), '@region', region))
  params: {
    apimGatewayOpenIdConnectPath: replace(replace('${apimGatewayName}/${apimGatewayOpenIdConnectName}', '@environment', environment), '@region', region)
    apimGatewayOpenIdConnectName: replace(replace(apimGatewayOpenIdConnectName, '@environment', environment), '@region', region)
    apimGatewayOpenIdConnectClientSecret: azKeyVaultReference.getSecret(keyVaultSecretName)
    apimGatewayOpenIdConnectClientId: contains(apimGatewayOpenIdConnectClientId, environment) ? apimGatewayOpenIdConnectClientId[environment] : apimGatewayOpenIdConnectClientId.default
    apimGatewayOpenIdConnectMetadataUrl: replace(replace(contains(apimGatewayOpenIdConnectMetadataUrl, environment) ? apimGatewayOpenIdConnectMetadataUrl[environment] : apimGatewayOpenIdConnectMetadataUrl.default, '@environment', environment), '@region', region)
  }
}

output apimOpenIdConnect object = azApimGatewayOpendIDConnectDeployment
