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
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: replace(replace(replace(storageAccountName, '@affix', affix), '@environment', environment), '@region', region)
}

// 2. Deploy the Storage Account Table Service
resource storageAccountTableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  name: storageAccountTableServiceName
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [for rule in storageAccountTableServiceConfigs.?tableServiceCorsPolicy ?? []: {
        allowedMethods: rule.methods
        allowedOrigins: rule.origins
        exposedHeaders: []
        allowedHeaders: rule.?headers ?? []
        maxAgeInSeconds: rule.?maxAge ?? 0
      }]
    }
  }
}

// 3. Deploy Storage Account Tables if applicable
module storageAccountTableServiceTable 'storage-account-table-services-table.bicep' = [for table in storageAccountTableServiceTables: if (!empty(table)) {
  name: !empty(storageAccountTableServiceTables) ? toLower('table-${guid('${storageAccountTableService.id}/${table.storageAccountTableName}')}') : 'no-table-service-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    storageAccountName: storageAccountName
    storageAccountTableServiceName: storageAccountTableServiceName
    storageAccountTableServiceTableName: table.storageAccountTableName
  }
}]

// 4. Deploy Storage Account Table Service Private Endpoint if applicable
module storageTableServicePrivateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(storageAccountTableServicePrivateEndpoint)) {
  name: !empty(storageAccountTableServicePrivateEndpoint) ? toLower('table-priv-endpoint-${guid('${storageAccountTableService.id}/${storageAccountTableServicePrivateEndpoint.privateEndpointName}')}') : 'no-stg-table-priv-endpoint'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    privateEndpointName: storageAccountTableServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation:storageAccountTableServicePrivateEndpoint.?privateEndpointLocation ?? storageAccountLocation
    privateEndpointDnsZoneGroupConfigs: storageAccountTableServicePrivateEndpoint.privateEndpointDnsZoneGroupConfigs
    privateEndpointVirtualNetworkName: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: storageAccountTableServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: storageAccount.id
    privateEndpointTags:  storageAccountTableServicePrivateEndpoint.?privateEndpointTag
    privateEndpointGroupIds: [
      'Table'
    ]
  }
}

output storageAccountTableService object = storageAccountTableService
