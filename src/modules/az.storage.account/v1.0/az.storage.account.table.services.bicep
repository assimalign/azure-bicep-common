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
@description('The name of the queue service to deploy')
param storageAccountTableServiceName string = 'default'

@description('')
param storageAccountTableServicePrivateEndpoint object = {}

@description('')
param storageAccountTables array = []



// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(storageAccountName, '@environment', environment)
}

// 2. Deploy the Storage Account Table Service
resource azStorageAccountTableServiceDeployment 'Microsoft.Storage/storageAccounts/tableServices@2021-04-01' = {
  name: storageAccountTableServiceName
  parent: azStorageAccountResource
}

// 3. Deploy Storage Account Tables if applicable
module azStorageAccountTablesDeployment 'az.storage.account.table.services.tables.bicep' = [for table in storageAccountTables: if(!empty(table)) {
  name: !empty(storageAccountTables) ? toLower('az-stg-table-${guid('${azStorageAccountTableServiceDeployment.id}/${table.name}')}') : 'no-table-service-to-deploy'
  scope: resourceGroup()
  params:{
    environment: environment
    storageAccountName: storageAccountName
    storageAccountTableName: table.name 
    storageAccountTableServiceName: storageAccountTableServiceName
  }
}]

// 4. Deploy Storage Account Table Service Private Endpoint if applicable
module azStorageTableServicePrivateEndpointDeployment '../az.private.endpoint/az.private.endpoint.bicep' = if(!empty(storageAccountTableServicePrivateEndpoint)) {
  name: !empty(storageAccountTableServicePrivateEndpoint) ? toLower('az-stg-table-priv-endpoint-${guid('${azStorageAccountTableServiceDeployment.id}/${storageAccountTableServicePrivateEndpoint.name}')}') : 'no-eg-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    privateEndpointName: storageAccountTableServicePrivateEndpoint.name
    privateEndpointPrivateDnsZone: storageAccountTableServicePrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-table-core-windows-net'
    privateEndpointPrivateDnsZoneResourceGroup: storageAccountTableServicePrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: storageAccountTableServicePrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: storageAccountTableServicePrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: storageAccountTableServicePrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azStorageAccountResource.id
    privateEndpointGroupIds: [
      'table'
    ]
  }
  dependsOn: [
    azStorageAccountTableServiceDeployment
  ]
}
