@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('')
param localNetGatewayName string








resource azLocalNetworkGatewayDeployment 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: replace('${localNetGatewayName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    
  }
}
