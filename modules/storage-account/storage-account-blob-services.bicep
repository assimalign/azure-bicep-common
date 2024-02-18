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
param storageAccountBlobServiceConfigs object = {}

func format(name string, env string, region string) string => replace(replace(name, '@environment', env), '@region', region)

// 1. Get the existing Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: format(storageAccountName, environment, region)
}

// 2. Deploy the Blob Service resource
resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: storageAccountBlobServiceName
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [for rule in storageAccountBlobServiceConfigs!.blobServiceCorsPolicy ?? []: {
        allowedMethods: rule.methods
        allowedOrigins: rule.origins
        exposedHeaders: []
        allowedHeaders: contains(rule, 'headers') ? rule.headers : []
        maxAgeInSeconds: contains(rule, 'maxAge') ? rule.maxAge : 0
      }]
    }
    automaticSnapshotPolicyEnabled: contains(storageAccountBlobServiceConfigs, 'blobServiceEnableSnapshot') ? storageAccountBlobServiceConfigs.blobServiceEnableSnapshot : false
    isVersioningEnabled: contains(storageAccountBlobServiceConfigs, 'blobServiceEnableVersioning') ? storageAccountBlobServiceConfigs.blobServiceEnableVersioning : false
    containerDeleteRetentionPolicy: any(contains(storageAccountBlobServiceConfigs, 'blobServiceRetentionPolicy') ? {
      days: storageAccountBlobServiceConfigs.blobServiceRetentionPolicy.days
      enabled: true
    } : json('null'))
    changeFeed: any(contains(storageAccountBlobServiceConfigs, 'blobServiceRestorePolicy') ? {
      retentionInDays: storageAccountBlobServiceConfigs.blobServiceRestorePolicy.days
      enabled: true
    } : json('null'))
    restorePolicy: any(contains(storageAccountBlobServiceConfigs, 'blobServiceRestorePolicy') ? {
      days: storageAccountBlobServiceConfigs.blobServiceRestorePolicy.days
      enabled: true
    } : json('null'))
    deleteRetentionPolicy: any(contains(storageAccountBlobServiceConfigs, 'blobServiceRetentionPolicy') ? {
      days: storageAccountBlobServiceConfigs.blobServiceRetentionPolicy.days
      enabled: true
    } : json('null'))
  }
}

// 3. Deploy any Blob Service Container if available
module storageAccountBlobServiceContainer 'storage-account-blob-services-container.bicep' = [for container in storageAccountBlobServiceContainers: if (!empty(container)) {
  name: !empty(storageAccountBlobServiceContainers) ? toLower('blob-container-${guid('${storageAccountBlobService.id}/${container.storageAccountBlobContainerName}')}') : 'no-container-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountBlobServiceName: storageAccountBlobServiceName
    storageAccountBlobContainerName: container.storageAccountBlobContainerName
    storageAccountBlobContainerPublicAccess: contains(container, 'storageAccountBlobContainerPublicAccess') ? container.storageAccountBlobContainerPublicAccess : 'None'
  }
}]

// 4. Deploy Storage Account Blob Service Private Endpoint if applicable
module storageBlobServicePrivateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(storageAccountBlobServicePrivateEndpoint)) {
  name: !empty(storageAccountBlobServicePrivateEndpoint) ? toLower('blob-priv-endpoint-${guid('${storageAccountBlobService.id}/${storageAccountBlobServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-blob-priv-endpoint'
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
    privateEndpointResourceIdLink: storageAccount.id
    privateEndpointTags: contains(storageAccountBlobServicePrivateEndpoint, 'privateEndpointTags') ? storageAccountBlobServicePrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'blob'
    ]
  }
}

output storageAccountBlobService object = storageAccountBlobService
