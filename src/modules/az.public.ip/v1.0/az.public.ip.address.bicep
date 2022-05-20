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

@description('The name of the Public IP Address')
param publicIpName string

@description('')
param publicIpLocation string = resourceGroup().location

@description('The pricing tier of the Public IP Address')
param publicIpSku object

@allowed([
  'Dynamic'
  'Static'
])
@description('The allocation method of the Public IP Address')
param publicIpAllocationMethod string = 'Dynamic'

@description('')
param publicIpTags object = {}



// 1. Deploy Public Ip Address
resource azPublicIpAddressDeployment 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: replace(replace('${publicIpName}', '@environment', environment), '@region', region)
  location: publicIpLocation
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
  tags: union(publicIpTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
