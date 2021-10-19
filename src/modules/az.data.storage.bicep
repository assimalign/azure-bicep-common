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
  'Storage'
  'StorageV2'
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
])
@description('The Storage Account type')
param storageAccountType string

@description('An object with evnironment spific pricing targets for the storage account')
param storageAccountTier object

@description('The access tier for the account. Hot or Cool')
param storageAccountAccessTier string = 'cool'

@allowed([
  'Allow'
  'Deny'
])
@description('Determines whether the storage account should be accessed by all networks or select ones by default')
param storageAccountDefaultNetworkAccess string = 'Allow'

@allowed([
  'AzureServices'
  'Metrics'
  'Logging'
  'None'
])
@description('Sets what services can bypass the storage accounts virtual network firewall')
param storageAccountVirtualNetworkBypass string = 'AzureServices'

@description('A list of Virtual Networks to allow Virtual Networks Access to this storage account')
param storageAccountVirtualNetworks array = []

@description('A list of resources and resource types to allow access to this storage account')
param storageAccountResourceAccess array = []

@description('')
param storageAccountIpRules array = []

@description('The data replication specs for the storage account')
param storageAccountRedundancy object

@description('Sets the minimum TLS version required to access the sotrage account')
param storageAccountTlsVersion string = 'TLS1_2'

@description('An array of Container, if any, to deploy with the storage account')
param storageAccountBlobServices object = {}

@description('A list of Tables to deploy under the storage account')
param storageAccountTableServices object = {}

@description('A list of Queues to deploy under the Storage Account')
param storageAccountQueueServices object = {}

@description('A list of File Shares to deploye under the storage account')
param storageAccountFileShareServices object = {}

@description('The tags to attach to the resource when deployed')
param storageAccountTags object = {}

// Setup the Virtual Networks Allowed or Denied for the Storage Account
var virtualNetworks = [for network in storageAccountVirtualNetworks: {
  action: network.allowAccess == true ? 'Allow' : null
  id: replace(resourceId('${network.virtualNetworkResourceGroup}', 'Microsoft.Network/virtualNetworks/subnets', '${network.virtualNetwork}', network.virtualNetworkSubnet), '@environment', environment)
}]

// Setup IP Rules for the virtualnetwork
var ipRules = [for ipRule in storageAccountIpRules: {
  action: 'Allow'
  value: ipRule.ipAddress
}]

// Setup allowed azure resource that can access the storage account
var resourceAccess = [for resource in storageAccountResourceAccess: {
  resourceId: replace(resourceId('${resource.resource}', 'Microsoft.Network/virtualNetworks/subnet', '${resource.resourceName}'), '@environment', environment)
}]

// 1. Deploy Azure Storage Account
resource azStorageAccountDeployment 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: replace(storageAccountName, '@environment', environment)
  kind: storageAccountType
  location: resourceGroup().location
  sku: any((environment == 'dev') ? {
    name: '${storageAccountTier.dev}_${toUpper(storageAccountRedundancy.dev)}'
    tier: storageAccountTier.dev
  } : any((environment) == 'qa') ? {
    name: '${storageAccountTier.qa}_${toUpper(storageAccountRedundancy.qa)}'
    tier: storageAccountTier.qa
  } : any((environment == 'uat') ? {
    name: '${storageAccountTier.uat}_${toUpper(storageAccountRedundancy.uat)}'
    tier: storageAccountTier.uat
  } : any((environment == 'prd') ? {
    name: '${storageAccountTier.prd}_${toUpper(storageAccountRedundancy.prd)}'
    tier: storageAccountTier.prd
  } : {
    name: '${storageAccountTier.dev}_${storageAccountRedundancy.dev}'
    tier: storageAccountTier.dev
  })))
  properties: {
    accessTier: storageAccountAccessTier
    minimumTlsVersion: storageAccountTlsVersion
    networkAcls: {
      defaultAction: storageAccountDefaultNetworkAccess
      virtualNetworkRules: virtualNetworks
      resourceAccessRules: resourceAccess
      ipRules: ipRules
      bypass: storageAccountVirtualNetworkBypass
    }
  }
  tags: storageAccountTags
}

// 2. Deploy Azure Storage Blob Services
module azStorageAccountBlobServiceDeployment 'az.data.storage.blob.services.bicep' = if (!empty(storageAccountBlobServices) && (startsWith(storageAccountType, 'Storage') || startsWith(storageAccountType, 'Blob'))) {
  name: !empty(storageAccountBlobServices) ? toLower('az-stg-blob-services-${guid('${azStorageAccountDeployment.id}/blob-service-deployment')}') : 'no-stg-blob-service-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    storageAccountName: storageAccountName
    storageAccountBlobServiceName: 'default'
    storageAccountBlobServiceContainers: storageAccountBlobServices.containers
    storageAccountBlobServicePrivateEndpoint: storageAccountBlobServices.privateEndpoint ?? {}
    storageAccountBlobServiceEnableSnapshot: storageAccountBlobServices.enableSnapshot
    storageAccountBlobServiceEnableVersioning: storageAccountBlobServices.enableVersioning
    storageAccountBlobServiceRestorePolicy: storageAccountBlobServices.restorePolicy ?? {}
    storageAccountBlobServiceRetentionPolicy: storageAccountBlobServices.retentionPolicy ?? {}
  }
  dependsOn: [
    azStorageAccountDeployment
  ]
}

// 3. Deploy Azure File Share Services
module azStorageAccountFileShareServiceDeployment 'az.data.storage.fileshare.services.bicep' = if (!empty(storageAccountFileShareServices) && (startsWith(storageAccountType, 'Storage') || startsWith(storageAccountType, 'FileStorage'))) {
  name: !empty(storageAccountFileShareServices) ? toLower('az-stg-fs-service-${guid('${azStorageAccountDeployment.id}/file-share-service-deployment')}') : 'no-stg-fs-service-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    storageAccountName: storageAccountName
    storageAccountFileShareServiceName: 'default'
    storageAccountFileShares: storageAccountFileShareServices.shares
    storageAccountFileShareServicePrivateEndpoint: storageAccountFileShareServices.privateEndpoint ?? {}
  }
  dependsOn: [
    azStorageAccountDeployment
  ]
}

// 4. Deploy Azure Queue Services
module azStorageAccountQueueServiceDeployment 'az.data.storage.queue.services.bicep' = if (!empty(storageAccountQueueServices) && startsWith(storageAccountType, 'Storage')) {
  name: !empty(storageAccountQueueServices) ? toLower('az-stg-queue-services-${guid('${azStorageAccountDeployment.id}/queues-service-deployment')}') : 'no-stg-queues-service-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    storageAccountName: storageAccountName
    storageAccountQueueServiceName: 'default'
    storageAccountQueues: storageAccountQueueServices.queues
    storageAccountQueueServiceCorsRules: storageAccountQueueServices.cors
    storageAccountQueueServicePrivateEndpoint: storageAccountQueueServices.privateEndpoint ?? {}
  }
  dependsOn: [
    azStorageAccountDeployment
  ]
}

// 5. Deploy Azure Queue Services
module azStorageAccountTableServiceDeployment 'az.data.storage.table.services.bicep' = if (!empty(storageAccountTableServices) && startsWith(storageAccountType, 'Storage')) {
  name: !empty(storageAccountTableServices) ? toLower('az-stg-table-services-${guid('${azStorageAccountDeployment.id}/table-service-deployment')}') : 'no-stg-table-service-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    storageAccountName: storageAccountName
    storageAccountTableServiceName: 'default'
    storageAccountTables: storageAccountTableServices.tables
    storageAccountTableServicePrivateEndpoint: storageAccountTableServices.privateEndpoint ?? {}
  }
  dependsOn: [
    azStorageAccountDeployment
  ]
}

output resource object = {
  resourceId: azStorageAccountDeployment.id
  name: azStorageAccountDeployment.name
  location: azStorageAccountDeployment.location
  properties: azStorageAccountDeployment.properties
  sku: azStorageAccountDeployment.sku
  tags: azStorageAccountDeployment.tags
  kind: azStorageAccountDeployment.kind
  apiVersion: azStorageAccountDeployment.apiVersion
}
