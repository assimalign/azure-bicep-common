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
@description('')
param storageAccountFileShareServiceName string = 'default'
@description('')
param storageAccountFileShareServicePrivateEndpoint object = {}

@description('The retention policy when deleting file shares.')
param storageAccountFileShareServiceConfigs object = {}

@description('A list of file shares to deploy with the file share service')
param storageAccountFileShareServiceFileShares array = []

// 1. Get the existing Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
}

// 2. Deploy the Storage Account File Share Service
resource storageAccountFileShareService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: storageAccountFileShareServiceName
  parent: storageAccount
  properties: {
    shareDeleteRetentionPolicy: !contains(storageAccountFileShareServiceConfigs, 'fileShareServiceRetentionPolicy') ? null : storageAccountFileShareServiceConfigs.fileShareServiceRetentionPolicy
    cors: {
      corsRules: [for rule in storageAccountFileShareServiceConfigs.?fileShareServiceCorsPolicy ?? []: {
        allowedMethods: rule.methods
        allowedOrigins: rule.origins
        exposedHeaders: []
        allowedHeaders: contains(rule, 'headers') ? rule.headers : []
        maxAgeInSeconds: contains(rule, 'maxAge') ? rule.maxAge : 0
      }]
    }
  }
}

// 3. Deploy the File Share Service if applicable
module storageAccountFileShares 'storage-account-fileshare-services-share.bicep' = [for fileShare in storageAccountFileShareServiceFileShares: if (!empty(fileShare)) {
  name: !empty(storageAccountFileShareServiceFileShares) ? toLower('fs-share-${guid('${storageAccountFileShareService.id}/${fileShare.storageAccountFileShareName}')}') : 'no-fs-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountFileShareServiceName: storageAccountFileShareServiceName
    storageAccountFileShareServiceShareName: fileShare.storageAccountFileShareName
    storageAccountFileShareServiceShareAccessTier: fileShare.storageAccountFileShareAccessTier
  }
}]

// 4. Deploy Storage Account File Share Service Private Endpoint if applicable
module storageFileShareServicePrivateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(storageAccountFileShareServicePrivateEndpoint)) {
  name: !empty(storageAccountFileShareServicePrivateEndpoint) ? toLower('fs-share-priv-endpoint-${guid('${storageAccountFileShareService.id}/${storageAccountFileShareServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-fs-priv-endpoint'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: storageAccountFileShareServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(storageAccountFileShareServicePrivateEndpoint, 'privateEndpointLocation') ? storageAccountFileShareServicePrivateEndpoint.privateEndpointLocation : storageAccountLocation
    privateEndpointDnsZoneName: storageAccountFileShareServicePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-file-core-windows-net'
    privateEndpointDnsZoneResourceGroup: storageAccountFileShareServicePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: storageAccountFileShareServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountFileShareServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountFileShareServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: storageAccount.id
    privateEndpointTags: contains(storageAccountFileShareServicePrivateEndpoint, 'privateEndpointTags') ? storageAccountFileShareServicePrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'file'
    ]
  }
}

output storageAccountFileShareService object = storageAccountFileShareService
