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
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
}

// 2. Deploy the Blob Service resource
resource azStorageAccountBlobServiceDeployment 'Microsoft.Storage/storageAccounts/blobServices@2021-08-01' = {
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
module azStorageAccountBlobServiceContainerDeployment 'az.storage.account.blob.services.container.bicep' = [for container in storageAccountBlobServiceContainers: if (!empty(container)) {
  name: !empty(storageAccountBlobServiceContainers) ? toLower('az-stg-blob-container-${guid('${azStorageAccountBlobServiceDeployment.id}/${container.name}')}') : 'no-container-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountBlobServiceName: storageAccountBlobServiceName
    storageAccountBlobServiceContainerName: container.name
    storageAccountBlobServiceContainerPublicAccess: container.publicAccess
    storageAccountBlobServiceContainerVersioningEnabled: container.enableVersioning
  }
}]

// 4. Deploy Storage Account Blob Service Private Endpoint if applicable
module azStorageBlobServicePrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(storageAccountBlobServicePrivateEndpoint)) {
  name: !empty(storageAccountBlobServicePrivateEndpoint) ? toLower('az-stg-blob-priv-endpoint-${guid('${azStorageAccountBlobServiceDeployment.id}/${storageAccountBlobServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-blob-priv-endpoint'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: storageAccountBlobServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(storageAccountBlobServicePrivateEndpoint, 'privateEndpointLocation') ? storageAccountBlobServicePrivateEndpoint.privateEndpointLocation : storageAccountLocation
    privateEndpointDnsZoneName: storageAccountBlobServicePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-blob-core-windows-net'
    privateEndpointDnsZoneResourceGroup: storageAccountBlobServicePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: storageAccountBlobServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountBlobServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountBlobServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'blob'
    ]
  }
}
