// This module is a support module which is need in order to use the key vault 'getSecret' function
// which acts as a pass through 

param apimGatewayOpenIdConnectPath string
param apimGatewayOpenIdConnectName string
param apimGatewayOpenIdConnectMetadataUrl string
param apimGatewayOpenIdConnectClientId string
@secure()
param apimGatewayOpenIdConnectClientSecret string

resource apimOpenIdConnectProvider 'Microsoft.ApiManagement/service/openidConnectProviders@2022-08-01' = {
  name: apimGatewayOpenIdConnectPath
  properties: {
    clientId: apimGatewayOpenIdConnectClientId
    clientSecret: apimGatewayOpenIdConnectClientSecret
    displayName: apimGatewayOpenIdConnectName
    metadataEndpoint: apimGatewayOpenIdConnectMetadataUrl
  }
}

output apimOpenIdConnectProvider object = apimOpenIdConnectProvider
