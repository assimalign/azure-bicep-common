@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('')
param localNetGatewayName string








resource azLocalNetworkGatewayDeployment 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: replace('${localNetGatewayName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    
  }
}
