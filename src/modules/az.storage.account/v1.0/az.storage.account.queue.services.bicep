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

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The location/region the Azure Storage Account instance is deployed to.')
param storageAccountLocation string = resourceGroup().location

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
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
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
  name: !empty(storageAccountQueueServiceQueues) ? toLower('az-stg-queues-${guid('${azStorageAccountQueueServiceDeployment.id}/${queue.name}')}') : 'no-queue-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountQueueName: queue.storageAccountQueueName
    storageAccountQueueServiceName: storageAccountQueueServiceName
  }
}]

// 4. Deploy Storage Account Queue Service Private Endpoint if applicable
module azStorageQueueServicePrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(storageAccountQueueServicePrivateEndpoint)) {
  name: !empty(storageAccountQueueServicePrivateEndpoint) ? toLower('az-stg-queue-priv-endpoint-${guid('${azStorageAccountQueueServiceDeployment.id}/${storageAccountQueueServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-queue-priv-endpoint'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: storageAccountQueueServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(storageAccountQueueServicePrivateEndpoint, 'privateEndpointLocation') ? storageAccountQueueServicePrivateEndpoint.privateEndpointLocation : storageAccountLocation
    privateEndpointDnsZoneName: storageAccountQueueServicePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-queue-core-windows-net'
    privateEndpointDnsZoneResourceGroup: storageAccountQueueServicePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountQueueServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'queue'
    ]
  }
}
