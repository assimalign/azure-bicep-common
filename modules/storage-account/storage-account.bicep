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

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

@description('A list of Virtual Networks to allow Virtual Networks Access to this storage account')
param storageAccountNetworkSettings object = {}

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy Azure Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: formatName(storageAccountName, affix, environment, region)
  kind: storageAccountType
  location: storageAccountLocation
  sku: any(contains(storageAccountTier, environment)
    ? {
        name: '${storageAccountTier[environment]}_${toUpper(storageAccountRedundancy[environment])}'
        tier: storageAccountTier[environment]
      }
    : {
        name: '${storageAccountTier.default}_${storageAccountRedundancy.default}'
        tier: storageAccountTier.default
      })
  properties: {
    accessTier: storageAccountAccessTier
    minimumTlsVersion: storageAccountTlsVersion
    publicNetworkAccess: storageAccountNetworkSettings.?allowPublicNetworkAccess ?? 'Enabled'
    networkAcls: {
      defaultAction: storageAccountNetworkSettings.?VirtualNetworkDefaultAccess ?? 'Allow'
      virtualNetworkRules: [
        for network in storageAccountNetworkSettings.?virtualNetworks ?? []: {
          action: network.?allowAccess ?? true
          id: resourceId(
            formatName(network.virtualNetworkResourceGroup, affix, environment, region),
            'Microsoft.Network/virtualNetworks/subnets',
            formatName(network.virtualNetwork, affix, environment, region),
            formatName(network.virtualNetworkSubnet, affix, environment, region)
          )
        }
      ]
      resourceAccessRules: [
        for resource in storageAccountNetworkSettings.?resourceAccess ?? []: {
          resourceId: resourceId(
            formatName(resource.resource, affix, environment, region),
            'Microsoft.Network/virtualNetworks/subnet',
            formatName(resource.resourceName, affix, environment, region)
          )
        }
      ]
      ipRules: [
        for ipRule in storageAccountNetworkSettings.?ipRules ?? []: {
          action: ipRule.?ipRule ?? 'Allow'
          value: ipRule.ipAddress
        }
      ]
      bypass: 'AzureServices'
    }
  }
  tags: union(storageAccountTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 2. Deploy Azure Storage Blob Services
module storageAccountBlobService 'storage-account-blob-services.bicep' = if (!empty(storageAccountBlobServices) && (startsWith(
  storageAccountType,
  'Storage'
) || startsWith(storageAccountType, 'Blob'))) {
  name: !empty(storageAccountBlobServices)
    ? toLower('blob-services-${guid('${storageAccount.id}/blob-service-deployment')}')
    : 'no-stg-blob-service-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountBlobServiceName: 'default'
    storageAccountBlobServiceConfigs: storageAccountBlobServices.?storageAccountBlobServiceConfigs
    storageAccountBlobServiceContainers: storageAccountBlobServices.?storageAccountBlobServiceContainers
    storageAccountBlobServicePrivateEndpoint: storageAccountBlobServices.?storageAccountBlobServicePrivateEndpoint
  }
}

// 3. Deploy Azure File Share Services
module storageAccountFileShareService 'storage-account-fileshare-services.bicep' = if (!empty(storageAccountFileShareServices) && (startsWith(
  storageAccountType,
  'Storage'
) || startsWith(storageAccountType, 'FileStorage'))) {
  name: !empty(storageAccountFileShareServices)
    ? toLower('fileshare-services-${guid('${storageAccount.id}/file-share-service-deployment')}')
    : 'no-stg-fs-service-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountFileShareServiceName: 'default'
    storageAccountFileShareServiceFileShares: storageAccountFileShareServices.?storageAccountFileShareServiceShares
    storageAccountFileShareServiceConfigs: storageAccountFileShareServices.?storageAccountFileShareServiceConfigs
    storageAccountFileShareServicePrivateEndpoint: storageAccountFileShareServices.?storageAccountFileShareServicePrivateEndpoint
  }
}

// 4. Deploy Azure Queue Services
module storageAccountQueueService 'storage-account-queue-services.bicep' = if (!empty(storageAccountQueueServices) && startsWith(
  storageAccountType,
  'Storage'
)) {
  name: !empty(storageAccountQueueServices)
    ? toLower('queue-services-${guid('${storageAccount.id}/queues-service-deployment')}')
    : 'no-stg-queues-service-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountQueueServiceName: 'default'
    storageAccountQueueServiceQueues: storageAccountQueueServices.?storageAccountQueueServiceQueues
    storageAccountQueueServiceConfigs: storageAccountQueueServices.?storageAccountQueueServiceConfigs
    storageAccountQueueServicePrivateEndpoint: storageAccountQueueServices.?storageAccountQueueServicePrivateEndpoint
  }
}

// 5. Deploy Azure Queue Services
module storageAccountTableService 'storage-account-table-services.bicep' = if (!empty(storageAccountTableServices) && startsWith(
  storageAccountType,
  'Storage'
)) {
  name: !empty(storageAccountTableServices)
    ? toLower('table-services-${guid('${storageAccount.id}/table-service-deployment')}')
    : 'no-stg-table-service-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountLocation: storageAccountLocation
    storageAccountTableServiceName: storageAccountTableServices.storageAccountTableServiceName
    storageAccountTableServiceTables: storageAccountTableServices.?storageAccountTableServiceTables
    storageAccountTableServiceConfigs: storageAccountTableServices.?storageAccountTableServiceConfigs
    storageAccountTableServicePrivateEndpoint: storageAccountTableServices.?storageAccountTableServicePrivateEndpoint
  }
}

output storageAccount object = storageAccount
