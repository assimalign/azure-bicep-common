@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Public IP Address')
param publicIpName string

@description('The pricing tier of the Public IP Address')
param publicIpSku object

@allowed([
  'Dynamic'
  'Static'
])
@description('The allocation method of the Public IP Address')
param publicIpAllocationMethod string = 'Dynamic'


// 1. Deploy Public Ip Address
resource azPublicIpAddressDeployment 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: replace('${publicIpName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod   
  }
  sku: any(environment == 'dev' ? {
    name: publicIpSku.dev
  } : any(environment == 'qa' ?   {
    name: publicIpSku.qa
  } : any(environment == 'uat' ?  {
    name: publicIpSku.uat
  } : any(environment == 'prd' ?  {
    name: publicIpSku.prd
  } : {
    name: 'Basic'
  }))))
}
