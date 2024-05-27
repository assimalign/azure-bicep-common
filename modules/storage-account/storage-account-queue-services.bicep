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

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The location/region the Azure Storage Account instance is deployed to.')
param storageAccountLocation string = resourceGroup().location

@allowed([
  'default'
])
@description('The name of the queue service to deploy')
param storageAccountQueueServiceName string = 'default'

@description('The List of CORS rules. You can include up to five CorsRule elements in the request.')
param storageAccountQueueServiceConfigs object = {}

@description('')
param storageAccountQueueServicePrivateEndpoint object = {}

@description('')
param storageAccountQueueServiceQueues array = []

// 1. Get the existing Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
}

// 2. Deploy the Storage Account Queue Service
resource storageAccountQueueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  name: storageAccountQueueServiceName
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [for rule in storageAccountQueueServiceConfigs.?queueServiceCorsPolicy ?? []: {
        allowedMethods: rule.methods
        allowedOrigins: rule.origins
        exposedHeaders: []
        allowedHeaders: contains(rule, 'headers') ? rule.headers : []
        maxAgeInSeconds: contains(rule, 'maxAge') ? rule.maxAge : 0
      }]
    }
  }
}

// 3. Deploy any Queues Service queues if any
module storageAccountQueues 'storage-account-queue-services-queue.bicep' = [for queue in storageAccountQueueServiceQueues: if (!empty(queue)) {
  name: !empty(storageAccountQueueServiceQueues) ? toLower('queues-${guid('${storageAccountQueueService.id}/${queue.storageAccountQueueName}')}') : 'no-queue-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountQueueServiceName: storageAccountQueueServiceName
    storageAccountQueueServiceQueueName: queue.storageAccountQueueName
  }
}]

// 4. Deploy Storage Account Queue Service Private Endpoint if applicable
module storageQueueServicePrivateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(storageAccountQueueServicePrivateEndpoint)) {
  name: !empty(storageAccountQueueServicePrivateEndpoint) ? toLower('queue-priv-endpoint-${guid('${storageAccountQueueService.id}/${storageAccountQueueServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-queue-priv-endpoint'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: storageAccountQueueServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(storageAccountQueueServicePrivateEndpoint, 'privateEndpointLocation') ? storageAccountQueueServicePrivateEndpoint.privateEndpointLocation : storageAccountLocation
    privateEndpointDnsZoneGroups: [
      for zone in storageAccountQueueServicePrivateEndpoint.privateEndpointDnsZoneGroupConfigs: {
        privateDnsZoneName: zone.privateDnsZone
        privateDnsZoneGroup: replace(zone.privateDnsZone, '.', '-')
        privateDnsZoneResourceGroup: zone.privateDnsZoneResourceGroup
      }
    ]
    privateEndpointVirtualNetworkName: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: storageAccount.id
    privateEndpointTags: contains(storageAccountQueueServicePrivateEndpoint, 'privateEndpointTags') ? storageAccountQueueServicePrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'queue'
    ]
  }
}

output storageAccountQueueService object = storageAccountQueueService
