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

@description('The name of the API Management resource')
param apimName string

@description('The location in which the APIM Gateway will be deployed to.')
param apimLocation string = resourceGroup().location

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

@description('The tags to attach to the resource when deployed')
param apimTags object = {}


resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = if(apimVirtualNetworkType != 'None') {
  name: replace(replace('${apimVirtualNetwork}/${apimVirtualNetworkSubnet}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(apimVirtualNetworkResourceGroup, '@environment', environment), '@region', region))
}

resource azApiManagementInstanceDeployment 'Microsoft.ApiManagement/service@2021-01-01-preview' = {
  name: replace(replace(apimName, '@environment', environment), '@region', region)
  location: apimLocation
  identity: {
   type: apimEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  sku: any(environment == 'dev' ? {
    name: apimSku.dev.name
    capacity: apimSku.dev.capacity
  }  : any(environment == 'qa' ? {
    name: apimSku.qa.name
    capacity: apimSku.qa.capacity
  }  : any(environment == 'uat' ? {
    name: apimSku.uat.name
    capacity: apimSku.uat.capacity
  }  : any(environment == 'prd' ? {
    name: apimSku.prd.name
    capacity: apimSku.prd.capacity
  }  : {
    name: apimSku.default.name
    capacity: apimSku.default.capacity
  }))))
  
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisher
    virtualNetworkType: apimVirtualNetworkType
    virtualNetworkConfiguration: any(apimVirtualNetworkType != 'None' ? {
      subnetResourceId: azVirtualNetworkSubnetResource.id
    } : json('null'))
  }
  tags: union(apimTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}



module azApimApisDeployment 'az.apim.apis.bicep' = [for api in apimApis: if(!empty(apimApis)) {
  name: !empty(apimApis) ? 'az-apim-apis-${guid('${apimName}/${api.name}')}' : 'no-apim-apis-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    apimName: apimName
    apimApiName: api.name
    apimApiPath: api.path
    apimApiDescription: api.description
  }
  dependsOn: [
    azApiManagementInstanceDeployment
  ]
}]
