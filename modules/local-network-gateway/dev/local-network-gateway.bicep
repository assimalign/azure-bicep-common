@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('')
param localNetGatewayName string





resource azLocalNetworkGatewayDeployment 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: replace('${localNetGatewayName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
     
  }
}
