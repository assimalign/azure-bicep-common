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
@description('The name of the blob storage container to deploy')
param storageAccountBlobServiceName string = 'default'

@description('')
param storageAccountBlobServicePrivateEndpoint object = {}

@description('')
param storageAccountBlobServiceContainers array = []

@description('')
param storageAccountBlobServiceRetentionPolicy object = {}

@description('')
param storageAccountBlobServiceRestorePolicy object = {}

@description('')
param storageAccountBlobServiceEnableVersioning bool = false

@description('')
param storageAccountBlobServiceEnableSnapshot bool = false


// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(storageAccountName, '@environment', environment)  
}

// 2. Deploy the Blob Service resource
resource azStorageAccountBlobServiceDeployment 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  name: storageAccountBlobServiceName
  parent: azStorageAccountResource
  properties: { 
    automaticSnapshotPolicyEnabled: storageAccountBlobServiceEnableSnapshot
    isVersioningEnabled: storageAccountBlobServiceEnableVersioning
    containerDeleteRetentionPolicy: any(!empty(storageAccountBlobServiceRetentionPolicy) ? {
      days: storageAccountBlobServiceRetentionPolicy.days
      enabled: true
    } : json('null'))
    changeFeed: any(!empty(storageAccountBlobServiceRestorePolicy) ? {
      enabled: true
    } : json('null'))
    restorePolicy: any(!empty(storageAccountBlobServiceRestorePolicy) ? {
      days: storageAccountBlobServiceRestorePolicy.days
      enabled: true
    } : json('null'))
    deleteRetentionPolicy: any(!empty(storageAccountBlobServiceRetentionPolicy) ? {
      days: storageAccountBlobServiceRetentionPolicy.days
      enabled: true
    } : json('null'))
  }
}

// 3. Deploy any Blob Service Container if available
module azStorageAccountBlobServiceContainerDeployment 'az.storage.account.blob.services.container.bicep' = [for container in storageAccountBlobServiceContainers: if(!empty(container)) {
  name: !empty(storageAccountBlobServiceContainers) ? toLower('az-stg-blob-container-${guid('${azStorageAccountBlobServiceDeployment.id}/${container.name}')}') : 'no-container-to-deploy'
  scope: resourceGroup()
  params:{
    environment: environment
    storageAccountName: storageAccountName
    storageAccountBlobServiceName: storageAccountBlobServiceName
    storageAccountBlobServiceContainerName: container.name
    storageAccountBlobServiceContainerPublicAccess: container.publicAccess
    storageAccountBlobServiceContainerVersioningEnabled: container.enableVersioning
  }
}]

// 4. Deploye the Blob Service Private Endpoint
module azStorageAccountBlobServicePrivateEndpointDeployment '../az.private.endpoint/az.private.endpoint.bicep' = if(!empty(storageAccountBlobServicePrivateEndpoint)) {
  name: !empty(storageAccountBlobServicePrivateEndpoint) ? toLower('az-stg-blob-priv-endpoint-${guid('${azStorageAccountBlobServiceDeployment.id}/${storageAccountBlobServicePrivateEndpoint.name}')}') : 'no-eg-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    privateEndpointName: storageAccountBlobServicePrivateEndpoint.name
    privateEndpointPrivateDnsZone: storageAccountBlobServicePrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-blob-core-windows-net'
    privateEndpointPrivateDnsZoneResourceGroup: storageAccountBlobServicePrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: storageAccountBlobServicePrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: storageAccountBlobServicePrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: storageAccountBlobServicePrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'blob'
    ]
  }
  dependsOn: [
    azStorageAccountBlobServiceDeployment
  ]
}
