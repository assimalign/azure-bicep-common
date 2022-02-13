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
@description('')
param storageAccountFileShareServiceName string = 'default'

@description('')
param storageAccountFileShareServicePrivateEndpoint object = {}

@description('A list of file shares to deploy with the file share service')
param storageAccountFileShareServiceFileShares array = []


// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
}

// 2. Deploy the Storage Account File Share Service
resource azStorageAccountFileShareServiceDeployment 'Microsoft.Storage/storageAccounts/fileServices@2021-08-01' = {
  name: storageAccountFileShareServiceName
  parent: azStorageAccountResource
}

// 3. Deploy the File Share Service if applicable
module azStorageAccountFileSharesDeployment 'az.storage.account.fileshare.services.shares.bicep' = [for fileShare in storageAccountFileShareServiceFileShares: if(!empty(fileShare)) {
  name: !empty(storageAccountFileShareServiceFileShares) ? toLower('az-stg-fs-share-${guid('${azStorageAccountFileShareServiceDeployment.id}/${fileShare.storageAccountFileShareName}')}') : 'no-fs-service-to-deploy'
  scope: resourceGroup()
  params:{
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountFileShareServiceName: storageAccountFileShareServiceName
    storageAccountFileShareName: fileShare.storageAccountFileShareName
    storageAccountFileAccessTier: fileShare.storageAccountFileShareAccessTier
  }
}]

// 4. Deploy Storage Account File Share Service Private Endpoint if applicable
module azStorageFileShareServicePrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(storageAccountFileShareServicePrivateEndpoint)) {
  name: !empty(storageAccountFileShareServicePrivateEndpoint) ? toLower('az-stg-fs-priv-endpoint-${guid('${azStorageAccountFileShareServiceDeployment.id}/${storageAccountFileShareServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-fs-priv-endpoint'
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
    privateEndpointResourceIdLink: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'file'
    ]
  }
}
