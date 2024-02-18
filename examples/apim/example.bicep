param region string
param environment string
param apimGateway object



module apim '../../modules/apim/apim.bicep' = {
  name: ''
  params: {
    apimGatewayName: apimGateway.apimGatewayName
    apimGatewayPublisher: apimGateway.apimGatewayPublisher
    apimGatewayPublisherEmail: apimGateway.apimGatewayPublisherEmail
    apimGatewaySku: apimGateway.apimGatewaySku
    
  }
}
