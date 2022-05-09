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

@description('')
param iotHubName string

@description('')
param iotHubLocation string = resourceGroup().location

@description('')
param iotHubSku object = {
  dev: 'B1'
  qa: 'B1'
  uat: 'B1'
  prd: 'B1'
}

@description('')
param iotHubTags object = {}


var sku = any((environment == 'dev') ? {
  name: iotHubSku.dev
} : any((environment == 'qa') ? {
  name: iotHubSku.qa
} : any((environment == 'uat') ? {
  name: iotHubSku.uat
} : any((environment == 'prd') ? {
  name: iotHubSku.prd
} : {
  name: 'B1'
}))))

resource azIotHubDeployment 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: replace(replace(iotHubName, '@environment', environment), '@region', region)
  location: iotHubLocation
  sku: sku
  properties: {
     
  }
  tags: iotHubTags
}

output resource object = azIotHubDeployment
