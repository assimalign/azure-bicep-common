@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Azure Signal R Service to be deployed.')
param signalRServiceName string

@description('The location the Azure Signal R Service will be deployed to.')
param signalRServiceLocation string = resourceGroup().location

@description('The pricing tier of the Azure Signal R Service.')
param signalRServiceSku object = {
  dev: 'free'
  qa:  'free'
  uat: 'free'
  prd: 'free'
}

@description('The tags to attach to the resource when deployed')
param signalRServiceTags object = {}


var skuCollection = {
  free: {
    name: 'Free_F1'
  }
  standard: {
    name: 'Standard_S1'
  }
}
var sku = any((environment == 'dev') ? {
  name: skuCollection[signalRServiceSku.dev].name
} : any((environment == 'qa') ? {
  name: skuCollection[signalRServiceSku.qa].name
} : any((environment == 'uat') ? {
  name: skuCollection[signalRServiceSku.uat].name
} : any((environment == 'prd') ? {
  name: skuCollection[signalRServiceSku.prd].name
} : {
  name: 'Free_F1'
}))))

resource azSignalRDeployment 'Microsoft.SignalRService/SignalR@2022-02-01' = {
  name: replace(replace(signalRServiceName, '@environment', environment), '@region', region)
  location: signalRServiceLocation
  sku: sku
  properties: {
    
  }
  tags: signalRServiceTags
}
