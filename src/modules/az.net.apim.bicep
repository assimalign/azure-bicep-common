@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the API Management resource')
param apimName string

@description('The organization name of the published gateway')
param apimPublisher string

@description('The email address of the publisher')
param apimPublisherEmail string

@description('')
param apimEnableMsi bool = false

@description('The pricing tier for the APIM resource')
param apimSku object // name and capacity

@allowed([
  'None'
  'Internal'
  'External'
])
@description('The network type for the virtual network to attach to the APIM')
param apimVirtualNetworkType string = 'None'

@description('The name of the virtual network to')
param apimVirtualNetwork string = 'no-network'

@description('The name of the virtual network subnet to attach to the APIM resource')
param apimVirtualNetworkSubnet string = 'no-network-subnet'

@description('The name of the resourceg group in which the virtual network lives in')
param apimVirtualNetworkResourceGroup string = resourceGroup().name

@description('')
param apimApis array = []


resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = if(apimVirtualNetworkType != 'None') {
  name: replace('${apimVirtualNetwork}/${apimVirtualNetworkSubnet}', '@environment', environment)
  scope: resourceGroup(replace(apimVirtualNetworkResourceGroup, '@environment', environment))
}

resource azApiManagementInstanceDeployment 'Microsoft.ApiManagement/service@2020-12-01' = {
  name: replace(apimName, '@environment', environment)
  location: resourceGroup().location
  identity: {
   type: apimEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  sku: any(environment == 'dev' ? {
    name: apimSku.dev.name
    capacity: apimSku.dev.capacity
  } : any(environment == 'qa' ? {
    name: apimSku.qa.name
    capacity: apimSku.qa.capacity
  } : any(environment == 'uat' ? {
    name: apimSku.uat.name
    capacity: apimSku.uat.capacity
  } : any(environment == 'prd' ? {
    name: apimSku.prd.name
    capacity: apimSku.prd.capacity
  } : {
    name: 'Developer'
    capacity: 1
  }))))
  
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisher
    virtualNetworkType: apimVirtualNetworkType
    virtualNetworkConfiguration: any(apimVirtualNetworkType != 'None' ? {
      subnetResourceId: azVirtualNetworkSubnetResource.id
    } : json('null'))
  }
}



module azApimApisDeployment 'az.net.apim.apis.bicep' = [for api in apimApis: if(!empty(api)) {
  name: !empty(apimApis) ? 'az-apim-apis-${guid('${apimName}/${api.name}')}' : 'no-apim-apis-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    apimName: apimName
    apimApiName: api.name
    apimApiPath: api.path
    apimApiEndpoint: api.endpoint
    apimApiDescription: api.description
  }
  dependsOn: [
    azApiManagementInstanceDeployment
  ]
}]
