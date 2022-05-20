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

@description('The location/region the Azure Storage Account will deploy to.')
param storageAccountLocation string = resourceGroup().location

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
  id: replace(replace(resourceId('${network.virtualNetworkResourceGroup}', 'Microsoft.Network/virtualNetworks/subnets', '${network.virtualNetwork}', network.virtualNetworkSubnet), '@environment', environment), '@region', region)
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
resource azStorageAccountDeployment 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
  kind: storageAccountType
  location: storageAccountLocation
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
    name: '${storageAccountTier.default}_${storageAccountRedundancy.default}'
    tier: storageAccountTier.default
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
  tags: union(storageAccountTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 2. Deploy Azure Storage Blob Services
module azStorageAccountBlobServiceDeployment 'az.storage.account.blob.services.bicep' = if (!empty(storageAccountBlobServices) && (startsWith(storageAccountType, 'Storage') || startsWith(storageAccountType, 'Blob'))) {
  name: !empty(storageAccountBlobServices) ? toLower('az-stg-blob-services-${guid('${azStorageAccountDeployment.id}/blob-service-deployment')}') : 'no-stg-blob-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountBlobServiceName: 'default'
    storageAccountBlobServiceConfigs: contains(storageAccountBlobServices, 'storageAccountBlobServiceConfigs') ? storageAccountBlobServices.storageAccountBlobServiceConfigs : {}
    storageAccountBlobServiceContainers: contains(storageAccountBlobServices, 'storageAccountBlobServiceContainers') ? storageAccountBlobServices.storageAccountBlobServiceContainers : []
    storageAccountBlobServicePrivateEndpoint: contains(storageAccountBlobServices, 'storageAccountBlobServicePrivateEndpoint') ? storageAccountBlobServices.storageAccountBlobServicePrivateEndpoint : {}
  }
}

// 3. Deploy Azure File Share Services
module azStorageAccountFileShareServiceDeployment 'az.storage.account.fileshare.services.bicep' = if (!empty(storageAccountFileShareServices) && (startsWith(storageAccountType, 'Storage') || startsWith(storageAccountType, 'FileStorage'))) {
  name: !empty(storageAccountFileShareServices) ? toLower('az-stg-fs-service-${guid('${azStorageAccountDeployment.id}/file-share-service-deployment')}') : 'no-stg-fs-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountFileShareServiceName: 'default'
    storageAccountFileShareServiceFileShares: contains(storageAccountFileShareServices, 'storageAccountFileShareServiceShares') ? storageAccountFileShareServices.storageAccountFileShareServiceShares : []
    storageAccountFileShareServiceConfigs: contains(storageAccountFileShareServices, 'storageAccountFileShareServiceConfigs') ? storageAccountFileShareServices.storageAccountFileShareServiceConfigs : {}
    storageAccountFileShareServicePrivateEndpoint: contains(storageAccountFileShareServices, 'storageAccountFileShareServicePrivateEndpoint') ? storageAccountFileShareServices.storageAccountFileShareServicePrivateEndpoint : {}
  }
}

// 4. Deploy Azure Queue Services
module azStorageAccountQueueServiceDeployment 'az.storage.account.queue.services.bicep' = if (!empty(storageAccountQueueServices) && startsWith(storageAccountType, 'Storage')) {
  name: !empty(storageAccountQueueServices) ? toLower('az-stg-queue-services-${guid('${azStorageAccountDeployment.id}/queues-service-deployment')}') : 'no-stg-queues-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountQueueServiceName: 'default'
    storageAccountQueueServiceQueues: contains(storageAccountQueueServices,'storageAccountQueueServiceQueues') ? storageAccountQueueServices.storageAccountQueueServiceQueues : []
    storageAccountQueueServiceConfigs: contains(storageAccountQueueServices,'storageAccountQueueServiceConfigs') ? storageAccountQueueServices.storageAccountQueueServiceConfigs : {}
    storageAccountQueueServicePrivateEndpoint: contains(storageAccountQueueServices, 'storageAccountQueueServicePrivateEndpoint') ? storageAccountQueueServices.storageAccountQueueServicePrivateEndpoint : {}
  }
}

// 5. Deploy Azure Queue Services
module azStorageAccountTableServiceDeployment 'az.storage.account.table.services.bicep' = if (!empty(storageAccountTableServices) && startsWith(storageAccountType, 'Storage')) {
  name: !empty(storageAccountTableServices) ? toLower('az-stg-table-services-${guid('${azStorageAccountDeployment.id}/table-service-deployment')}') : 'no-stg-table-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountTableServiceName: storageAccountTableServices.storageAccountTableServiceName
    storageAccountTableServiceTables: storageAccountTableServices.storageAccountTableServiceTables
    storageAccountTableServiceConfigs: contains(storageAccountTableServices, 'storageAccountTableServiceConfigs') ? storageAccountTableServices.storageAccountTableServiceConfigs : {}
    storageAccountTableServicePrivateEndpoint: contains(storageAccountTableServices, 'storageAccountTableServicePrivateEndpoint') ? storageAccountTableServices.storageAccountTableServicePrivateEndpoint : {}
  }
}

output storageAccount object = {
  resourceId: azStorageAccountDeployment.id
  name: azStorageAccountDeployment.name
  location: azStorageAccountDeployment.location
  properties: azStorageAccountDeployment.properties
  sku: azStorageAccountDeployment.sku
  tags: azStorageAccountDeployment.tags
  kind: azStorageAccountDeployment.kind
  apiVersion: azStorageAccountDeployment.apiVersion
}
