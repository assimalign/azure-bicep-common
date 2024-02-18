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


resource azIotHubDeployment 'Microsoft.Devices/IotHubs@2023-06-30' = {
  name: replace(replace(iotHubName, '@environment', environment), '@region', region)
  location: iotHubLocation
  sku: contains(iotHubSku, environment) ? {
    name: iotHubSku[environment].name
    capacity: iotHubSku[environment].capacity
  } : {
    name: iotHubSku.default.name
    capacity: iotHubSku.default.capacity
  }
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
