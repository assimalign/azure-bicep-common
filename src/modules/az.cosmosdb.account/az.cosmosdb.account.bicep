@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix for the resource name')
param location string = ''

@description('The name of the Database Account/Server to be deployed')
param cosmosDbAccountName string

@description('The deployment location of the Document Db Account')
param cosmosDbAccountLocations array

@description('The Cors policy for the Document Db Account')
param cosmosDbAccountCorsPolicy array = []

@description('The consitency policy for how data will be persisted')
param cosmosDbAccountConsistencyPolicy object = {}

@description('The list of databases to deploy with the Document Db Account')
param cosmosDbAccountDatabases array = []

@description('A list of Document Db Tables for Table API deployment database account')
param cosmosDbAccountTables array = []

@description('Enables System Managed Identity for this resource')
param cosmosDbAccountEnableMsi bool = false

@description('Enables multi region writes')
param cosmosDbAccountEnableMultiRegionWrites bool = false

@description('Enables free compute up to certain amount. Only good for one resource per subscription.')
param cosmosDbAccountEnableFreeTier bool = true

@description('Custom attributes to attach to the document db deployment')
param cosmosDbAccountTags object = {}

// **************************************************************************************** //
//                             Cosmos DB Account Deployment                                 //
// **************************************************************************************** //

// 1. Deploy the Document Db Account
resource azCosmosDbAccountDeployment 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: replace(replace('${cosmosDbAccountName}', '@environment', environment), '@location', location)
  kind: 'GlobalDocumentDB'
  location: first(cosmosDbAccountLocations).locationName
  identity: {
    type: cosmosDbAccountEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    enableFreeTier: cosmosDbAccountEnableFreeTier
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: !empty(cosmosDbAccountConsistencyPolicy) ? cosmosDbAccountConsistencyPolicy.consistencyLevel : 'Session'
    }
    // This will enable Table Storage APIs rather than 
    capabilities: any(length(cosmosDbAccountTables) > 0 && !empty(first(cosmosDbAccountTables)) && empty(first(cosmosDbAccountDatabases)) ? [
      {
        name: 'EnableTable'
      }
    ] : [])
    enableMultipleWriteLocations: cosmosDbAccountEnableMultiRegionWrites
    locations: cosmosDbAccountLocations
    cors: cosmosDbAccountCorsPolicy
  }
  tags: cosmosDbAccountTags
}

// 2. Deploy Cosmos DB Table API(s), if applicable
module azCosmosDbAccounTableDeployment 'az.cosmosdb.account.table.bicep' = [for table in cosmosDbAccountTables: if (!empty(cosmosDbAccountTables)) {
  name: !empty(cosmosDbAccountTables) ? toLower('az-cosmosdb-tables-api-${guid('${azCosmosDbAccountDeployment.id}/${table.name}')}') : 'no-cosmosdb-tables-api-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbAccountTableName: table.name
  }
}]

// 3. Deploy Cosmos DB Containers, if applicable
module azCosmosDbAccountDatabaseDeployment 'az.cosmosdb.account.database.bicep' = [for database in cosmosDbAccountDatabases: if (!empty(cosmosDbAccountDatabases)) {
  name: !empty(cosmosDbAccountDatabases) ? toLower('az-cosmosdb-database-${guid('${azCosmosDbAccountDeployment.id}/${database.cosmosDatabaseName}')}') : 'no-cosmosdb-databases-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbAccountDatabaseName: database.cosmosDatabaseName
    cosmosDbAccountDatabaseContainers: database.cosmosDatabaseContainers
  }
}]

// 4. Return Deployment Output
output resource object = azCosmosDbAccountDeployment
