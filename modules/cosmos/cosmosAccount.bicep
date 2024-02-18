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

@description('The name of the Database Account/Server to be deployed')
param cosmosAccountName string

@allowed([
  'EnableDocument'
  'EnableTable'
  'EnableGremlin'
])
@description('')
param cosmosAccountType string = 'EnableDocument'

@description('The deployment location of the Document Db Account')
param cosmosAccountLocations array

@description('The Cors policy for the Document Db Account')
param cosmosAccountCorsPolicy array = []

@description('The consitency policy for how data will be persisted')
param cosmosAccountConsistencyPolicy object = {}

@description('The list of databases to deploy with the Document Db Account')
param cosmosAccountDatabases array = []

@description('Enables System Managed Identity for this resource')
param cosmosAccountEnableMsi bool = false

@description('Enables multi region writes')
param cosmosAccountEnableMultiRegionWrites bool = false

@description('Enables free compute up to certain amount. Only good for one resource per subscription.')
param cosmosAccountEnableFreeTier bool = true

@description('')
param cosmosAccountPrivateEndpoint object = {}

@description('')
param cosmosAccountVirtualNetworks array = []

@description('')
param cosmosAccountConfigs object = {}

@description('')
param cosmosAccountBackupPolicy object = {}

@description('Custom attributes to attach to the document db deployment')
param cosmosAccountTags object = {}

// 1. Deploy the Document Db Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: replace(replace(cosmosAccountName, '@environment', environment), '@region', region)
  kind: 'GlobalDocumentDB'
  location: first(cosmosAccountLocations).locationName
  identity: {
    type: cosmosAccountEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    enableFreeTier: cosmosAccountEnableFreeTier
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: !empty(cosmosAccountConsistencyPolicy) ? cosmosAccountConsistencyPolicy.consistencyLevel : 'Session'
    }
    backupPolicy: empty(cosmosAccountBackupPolicy) ? null : cosmosAccountBackupPolicy.policyType == 'Periodic' ? {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: cosmosAccountBackupPolicy.policyBackupInternal
        backupRetentionIntervalInHours: cosmosAccountBackupPolicy.policyBackupRetentionInterval
        backupStorageRedundancy: cosmosAccountBackupPolicy.policyBackupStorageRedundancy
      }
    } : {
      type: 'Continuous'
      migrationState: {
        startTime: cosmosAccountBackupPolicy.policyBackupStartTime
        targetType: cosmosAccountBackupPolicy.policyBackupTargetType
      }
    }
    isVirtualNetworkFilterEnabled: contains(cosmosAccountConfigs, 'enableVirtualNetworkFiltering') ? cosmosAccountConfigs.enableVirtualNetworkFiltering : true
    publicNetworkAccess: contains(cosmosAccountConfigs, 'disablePublicNetworkAccess') && cosmosAccountConfigs.disablePublicNetworkAccess == true ? 'Disabled' : 'Enabled'
    disableLocalAuth: contains(cosmosAccountConfigs, 'disableLocalAuth') ? cosmosAccountConfigs.disableLocalAuth : false
    virtualNetworkRules: [for vnet in cosmosAccountVirtualNetworks: any({
      id: any(replace(replace(resourceId(vnet.virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnet.virtualNetworkName, vnet.virtualNetworkSubnetName), '@environment', environment), '@region', region))
      ignoreMissingVNetServiceEndpoint: contains(vnet, 'VirtualNetworkMissingServiceEndpointIgnore') ? vnet.VirtualNetworkMissingServiceEndpointIgnore : true
    })]
    // This will enable Table Storage APIs rather than 
    capabilities: any(cosmosAccountType != 'EnableDocument' ? [
      {
        name: cosmosAccountType
      }
    ] : [])
    enableMultipleWriteLocations: cosmosAccountEnableMultiRegionWrites
    locations: cosmosAccountLocations
    cors: cosmosAccountCorsPolicy
  }
  tags: union(cosmosAccountTags, {
      region: region
      environment: environment
    })
}

// 2. Deploy Cosmos DB Document Database, if applicable
module cosmosAccountDocumentDatabase 'cosmosAccountDocumentDatabase.bicep' = [for database in cosmosAccountDatabases: if (!empty(cosmosAccountDatabases) && cosmosAccountType == 'EnableDocument') {
  name: !empty(cosmosAccountDatabases) ? toLower('cdb-docdb-${guid('${cosmosAccount.id}/${database.cosmosAccountDatabaseName}')}') : 'no-cosmosdb-document-databases-to-deploy'
  params: {
    region: region
    environment: environment
    cosmosAccountName: cosmosAccountName
    cosmosAccountDatabaseName: database.cosmosAccountDatabaseName
    cosmosAccountDatabaseContainers: contains(database, 'cosmosAccountDatabaseContainers') ? database.cosmosAccountDatabaseContainers : []
  }
}]

// 3. Deploy Cosmos DB Graph Database, if applicable
module cosmosAccountGraphDatabase 'cosmosAccountGraphDatabase.bicep' = [for database in cosmosAccountDatabases: if (!empty(cosmosAccountDatabases) && cosmosAccountType == 'EnableGremlin') {
  name: !empty(cosmosAccountDatabases) ? toLower('az-cosmosdb-graphdb-${guid('${cosmosAccount.id}/${database.cosmosAccountDatabaseName}')}') : 'no-cosmosdb-graph-databases-to-deploy'
  params: {
    region: region
    environment: environment
    cosmosAccountName: cosmosAccountName
    cosmosAccountDatabaseName: database.cosmosAccountDatabaseName
    cosmosAccountDatabaseContainers: contains(database, 'cosmosAccountDatabaseContainers') ? database.cosmosAccountDatabaseContainers : []
  }
}]

// 4. Deploys a private endpoint, if applicable, for an instance of Azure Document DB Account
module cosmosAccountPrivateEp '../private-endpoint/privateEndpoint.bicep' = if (!empty(cosmosAccountPrivateEndpoint)) {
  name: !empty(cosmosAccountPrivateEndpoint) ? toLower('cdb-private-ep-${guid('${cosmosAccount.id}/${cosmosAccountPrivateEndpoint.privateEndpointName}')}') : 'no-cosmosdb-priv-endp-to-deploy'
  params: {
    region: region
    environment: environment
    privateEndpointName: cosmosAccountPrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(cosmosAccountPrivateEndpoint, 'privateEndpointLocation') ? cosmosAccountPrivateEndpoint.privateEndpointLocation : first(cosmosAccountLocations).privateEndpointLocation
    privateEndpointDnsZoneName: cosmosAccountPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-documents-azure-com'
    privateEndpointDnsZoneResourceGroup: cosmosAccountPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: cosmosAccountPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: cosmosAccountPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: cosmosAccountPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: cosmosAccount.id
    privateEndpointTags: contains(cosmosAccountPrivateEndpoint, 'privateEndpointTags') ? cosmosAccountPrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'Sql'
    ]
  }
}

// 5. Return Deployment Output
output cosmosAccount object = cosmosAccount
