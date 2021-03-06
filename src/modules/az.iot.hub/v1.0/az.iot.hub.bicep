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

@description('')
param iotHubName string

@description('')
param iotHubLocation string = resourceGroup().location

@description('')
param iotHubSku object = {
  dev: {
    name: 'F1'
    capacity: 1
  }
  qa: {
    name: 'F1'
    capacity: 1
  }
  uat: {
    name: 'F1'
    capacity: 1
  } 
  prd: {
    name: 'F1'
    capacity: 1
  } 
  default: {
    name: 'F1'
    capacity: 1
  }
}
@description('')
param iotHubMsiEnabled bool = false

@description('If true, SAS tokens with Iot hub scoped SAS keys cannot be used for authentication.')
param iotHubDisableLocalAuth bool = false

@description('')
param iotHubScale object = {}

@description('')
param iotHubTags object = {}

var sku = any((environment == 'dev') ? {
  name: iotHubSku.dev.name
  capacity: iotHubSku.dev.capacity
} : any((environment == 'qa') ? {
  name: iotHubSku.qa.name
  capacity: iotHubSku.qa.capacity
} : any((environment == 'uat') ? {
  name: iotHubSku.uat.name
  capacity: iotHubSku.uat.capacity
} : any((environment == 'prd') ? {
  name: iotHubSku.prd.name
  capacity: iotHubSku.prd.capacity
} : {
  name: iotHubSku.default.name
  capacity: iotHubSku.default.capacity
}))))

resource azIotHubDeployment 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: replace(replace(iotHubName, '@environment', environment), '@region', region)
  location: iotHubLocation
  sku: sku
  identity: {
    type: iotHubMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    minTlsVersion: '1.2' // Let's force users to not use 1.1
    disableLocalAuth: iotHubDisableLocalAuth
    features: 'None'
    eventHubEndpoints: {
      events: {
        partitionCount: contains(iotHubScale, 'partitions') ? iotHubScale.partitions : 2
        retentionTimeInDays: contains(iotHubScale, 'retention') ? iotHubScale.retention : 1
      }
    }
  }
  tags: union(iotHubTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}


output iotHub object = azIotHubDeployment
