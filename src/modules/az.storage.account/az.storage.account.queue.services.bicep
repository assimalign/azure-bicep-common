@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@allowed([
  'default'
])
@description('The name of the queue service to deploy')
param storageAccountQueueServiceName string = 'default'

@description('')
param storageAccountQueueServiceCorsRules array = []

@description('')
param storageAccountQueueServicePrivateEndpoint object = {}

@description('')
param storageAccountQueueServiceQueues array = []



// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(storageAccountName, '@environment', environment)
}

// 2. Deploy the Storage Account Queue Service
resource azStorageAccountQueueServiceDeployment 'Microsoft.Storage/storageAccounts/queueServices@2021-04-01' = {
  name: storageAccountQueueServiceName
  parent: azStorageAccountResource
  properties: {
    cors: {
      corsRules: storageAccountQueueServiceCorsRules
    }
  }
}

// 3. Deploy any Queues Service queues if any
module azStorageAccountQueuesDeployment 'az.storage.account.queue.services.queues.bicep' = [for queue in storageAccountQueueServiceQueues: if (!empty(queue)) {
  name: !empty(storageAccountQueueServiceQueues) ? toLower('az-stg-fs-share-${guid('${azStorageAccountQueueServiceDeployment.id}/${queue.name}')}') : 'no-queue-service-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    storageAccountName: storageAccountName
    storageAccountQueueName: queue.name
    storageAccountQueueServiceName: storageAccountQueueServiceName
  }
}]

// 4. Deploy Queue Service Private Endpoint if applicable
module azStorageQueueServicePrivateEndpointDeployment '../az.private.endpoint/az.private.endpoint.bicep' = if (!empty(storageAccountQueueServicePrivateEndpoint)) {
  name: !empty(storageAccountQueueServicePrivateEndpoint) ? toLower('az-stg-queue-priv-endpoint-${guid('${azStorageAccountQueueServiceDeployment.id}/${storageAccountQueueServicePrivateEndpoint.name}')}') : 'no-eg-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    privateEndpointName: storageAccountQueueServicePrivateEndpoint.name
    privateEndpointPrivateDnsZone: storageAccountQueueServicePrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-queue-core-windows-net'
    privateEndpointPrivateDnsZoneResourceGroup: storageAccountQueueServicePrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: storageAccountQueueServicePrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: storageAccountQueueServicePrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: storageAccountQueueServicePrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'queue'
    ]
  }
}
