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
@description('The name of the queue service to deploy')
param storageAccountTableServiceName string = 'default'

@description('')
param storageAccountTableServiceTables array = []

@description('Sets the CORS rules. You can include up to five CorsRule elements in the request.')
param storageAccountTableServiceConfigs object = {}

@description('')
param storageAccountTableServicePrivateEndpoint object = {}

// 1. Get the existing Storage Account
resource azStorageAccountResource 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: replace(replace(storageAccountName, '@environment', environment), '@region', region)
}

// 2. Deploy the Storage Account Table Service
resource azStorageAccountTableServiceDeployment 'Microsoft.Storage/storageAccounts/tableServices@2022-05-01' = {
  name: storageAccountTableServiceName
  parent: azStorageAccountResource
  properties: {
    cors: !contains(storageAccountTableServiceConfigs, 'tableServiceCorsPolicy') ? json('null') : {
      corsRules: storageAccountTableServiceConfigs.tableServiceCorsPolicy
    }
  }
}

// 3. Deploy Storage Account Tables if applicable
module azStorageAccountTableServiceTablesDeployment 'az.storage.account.table.services.tables.bicep' = [for table in storageAccountTableServiceTables: if (!empty(table)) {
  name: !empty(storageAccountTableServiceTables) ? toLower('az-stg-table-${guid('${azStorageAccountTableServiceDeployment.id}/${table.storageAccountTableName}')}') : 'no-table-service-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountTableServiceName: storageAccountTableServiceName
    storageAccountTableServiceTableName: table.storageAccountTableName
  }
}]

// 4. Deploy Storage Account Table Service Private Endpoint if applicable
module azStorageTableServicePrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(storageAccountTableServicePrivateEndpoint)) {
  name: !empty(storageAccountTableServicePrivateEndpoint) ? toLower('az-stg-table-priv-endpoint-${guid('${azStorageAccountTableServiceDeployment.id}/${storageAccountTableServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-table-priv-endpoint'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: storageAccountTableServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(storageAccountTableServicePrivateEndpoint, 'privateEndpointLocation') ? storageAccountTableServicePrivateEndpoint.privateEndpointLocation : storageAccountLocation
    privateEndpointDnsZoneName: storageAccountTableServicePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-table-core-windows-net'
    privateEndpointDnsZoneResourceGroup: storageAccountTableServicePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azStorageAccountResource.id
    privateEndpointTags: contains(storageAccountTableServicePrivateEndpoint, 'privateEndpointTags') ? storageAccountTableServicePrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'table'
    ]
  }
}

output storageAccountTableService object = azStorageAccountTableServiceDeployment
