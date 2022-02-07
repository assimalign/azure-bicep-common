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
@description('')
param storageAccountFileShareServiceName string = 'default'

@description('')
param storageAccountFileShareServicePrivateEndpoint object = {}

@description('A list of file shares to deploy with the file share service')
param storageAccountFileShareServiceFileShares array = []


// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(storageAccountName, '@environment', environment)  
}

// 2. Deploy the Storage Account File Share Service
resource azStorageAccountFileShareDeployment 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' = {
  name: storageAccountFileShareServiceName
  parent: azStorageAccountResource
}

// 3. Deploy the File Share Service if applicable
module azStorageAccountFileSharesDeployment 'az.storage.account.fileshare.services.shares.bicep' = [for fileShare in storageAccountFileShareServiceFileShares: if(!empty(fileShare)) {
  name: !empty(storageAccountFileShareServiceFileShares) ? toLower('az-stg-fs-share-${guid('${azStorageAccountFileShareDeployment.id}/${fileShare.name}')}') : 'no-file-share-service-to-deploy'
  scope: resourceGroup()
  params:{
    environment: environment
    storageAccountName: storageAccountName
    storageAccountFileShareServiceName: storageAccountFileShareServiceName
    storageAccountFileShareName: fileShare.name
    storageAccountFileAccessTier: fileShare.accessTier
  }
}]

// 4. Deploy the File Share Service Private Endpoint if applicable
module azStorageFileSharePrivateEndpointDeployment '../az.private.endpoint/az.private.endpoint.bicep' = if(!empty(storageAccountFileShareServicePrivateEndpoint)) {
  name: !empty(storageAccountFileShareServicePrivateEndpoint) ? toLower('az-stg-fs-priv-endpoint-${guid('${azStorageAccountFileShareDeployment.id}/${storageAccountFileShareServicePrivateEndpoint.name}')}') : 'no-eg-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    privateEndpointName: storageAccountFileShareServicePrivateEndpoint.name
    privateEndpointPrivateDnsZone: storageAccountFileShareServicePrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-file-core-windows-net'
    privateEndpointPrivateDnsZoneResourceGroup: storageAccountFileShareServicePrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: storageAccountFileShareServicePrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: storageAccountFileShareServicePrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: storageAccountFileShareServicePrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'file'
    ]
  }
}
