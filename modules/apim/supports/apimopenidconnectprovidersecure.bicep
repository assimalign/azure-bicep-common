// This module is a support module which is need in order to use the key vault 'getSecret' function
// which acts as a pass through 

param apimGatewayOpenIdConnectPath string
param apimGatewayOpenIdConnectName string
param apimGatewayOpenIdConnectMetadataUrl string
param apimGatewayOpenIdConnectClientId string
@secure()
param apimGatewayOpenIdConnectClientSecret string

resource azApimGatewayOpendIDConnectDeployment 'Microsoft.ApiManagement/service/openidConnectProviders@2021-12-01-preview' = {
  name: apimGatewayOpenIdConnectPath
  properties: {
    clientId: apimGatewayOpenIdConnectClientId
    clientSecret: apimGatewayOpenIdConnectClientSecret
    displayName: apimGatewayOpenIdConnectName
    metadataEndpoint: apimGatewayOpenIdConnectMetadataUrl
  }
}

output apimOpenIdConnect object = azApimGatewayOpendIDConnectDeployment
