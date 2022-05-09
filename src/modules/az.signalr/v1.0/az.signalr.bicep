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
  dev: 'Free_F1'
  qa: 'Free_F1'
  uat: 'Free_F1'
  prd: 'Free_F1'
}

@description('The tags to attach to the resource when deployed')
param signalRServiceTags object = {}

var sku = any((environment == 'dev') ? {
  name: signalRServiceSku.dev
} : any((environment == 'qa') ? {
  name: signalRServiceSku.qa
} : any((environment == 'uat') ? {
  name: signalRServiceSku.uat
} : any((environment == 'prd') ? {
  name: signalRServiceSku.prd
} : {
  name: 'Free'
}))))

resource azSignalRDeployment 'Microsoft.SignalRService/SignalR@2022-02-01' = {
  name: replace(replace(signalRServiceName, '@environment', environment), '@region', region)
  location: signalRServiceLocation
  sku: sku
  properties: {
     
  }
  tags: signalRServiceTags
}
