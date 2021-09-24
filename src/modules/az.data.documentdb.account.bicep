@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Database Account/Server to be deployed')
param dbAccountName string

@description('The deployment location of the Document Db Account')
param dbAccountLocations array

@description('The Cors policy for the Document Db Account')
param dbAccountCorsPolicy array = []

@description('The consitency policy for how data will be persisted')
param dbAccountConsistencyPolicy object = {}

@description('The list of databases to deploy with the Document Db Account')
param dbAccountDatabases array = []

@description('A list of Document Db Tables for Table API deployment database account')
param dbAccountTables array = []

@description('Enables System Managed Identity for this resource')
param dbAccountEnableMsi bool = false

@description('Enables multi region writes')
param dbAccountEnableMultiRegionWrites bool = false

@description('Enables free compute up to certain amount. Only good for one resource per subscription.')
param dbAccountEnableFreeTier bool = true



// 1. Deploy the Document Db Account
resource azDocumentDbAccountDeployment 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: replace('${dbAccountName}', '@environment', environment)
  kind: 'GlobalDocumentDB'
  location: first(dbAccountLocations).locationName
  identity: {
    type: dbAccountEnableMsi == true ? 'SystemAssigned'  : 'None'
  }
  properties: {
    enableFreeTier: dbAccountEnableFreeTier
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: !empty(dbAccountConsistencyPolicy) ? dbAccountConsistencyPolicy.consistencyLevel : 'Session'
    }
    // This will enable Table Storage APIs rather than 
    capabilities: any(length(dbAccountTables) > 0 && !empty(first(dbAccountTables)) && empty(first(dbAccountDatabases)) ? [
      {
        name: 'EnableTable'
      }
    ] : [])
    enableMultipleWriteLocations: dbAccountEnableMultiRegionWrites
    locations: dbAccountLocations
    cors: dbAccountCorsPolicy 
  }
}


module azDocumentDbAccounTableDeployment 'az.data.documentdb.account.table.bicep' = [for table in dbAccountTables: if(!empty(table)){
  name: !empty(dbAccountTables) ? toLower('az-documentdb-tableapi-${guid('${azDocumentDbAccountDeployment.id}/${table.name}')}') : 'no-documentdb-tables-to-deploy'
  scope: resourceGroup()
  params: {
     environment: environment
     dbAccountName: dbAccountName
     dbAccountTableName: table.name 
  }
  dependsOn: [
    azDocumentDbAccountDeployment
  ]
}]


module azDocumentDbAccountDatabaseDeployment 'az.data.documentdb.account.database.bicep' = [for database in dbAccountDatabases: if (!empty(database)) {
  name: !empty(dbAccountDatabases) ? toLower('az-documentdb-database-${guid('${azDocumentDbAccountDeployment.id}/${database.name}')}') : 'no-documentdb-databases-to-deploy'
  scope: resourceGroup()
  params: {
     environment: environment
     dbAccountName: dbAccountName
     dbAccountDatabaseName: database.name 
     dbAccountDatabaseContainers: database.containers
  }
  dependsOn: [
    azDocumentDbAccountDeployment
  ]
}]


output resource object = azDocumentDbAccountDeployment
