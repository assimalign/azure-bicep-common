@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The Cosmos Document Db Name')
param cosmosDbAccountName string

@description('The Cosmos Document Db Database Name')
param cosmosDbAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param cosmosDbAccountDatabaseContainers array = []


// 1. Deploy the Document Database
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: replace(replace('${cosmosDbAccountName}/${cosmosDbAccountDatabaseName}', '@environment', environment), '@location', location)
  properties: {
    resource: {
      id: replace(replace(cosmosDbAccountDatabaseName, '@environment', environment), '@location', location)
    }
  }
}

// 2. Deploye Document DB Database Containers
module azDocumentDbAccountDatabaseContainerDeployment 'az.cosmosdb.account.database.container.bicep' = [for container in cosmosDbAccountDatabaseContainers: if(!empty(container)) {
  name: !empty(cosmosDbAccountDatabaseContainers) ? toLower('az-docdb-container-${guid('${azDocumentDbAccountDatabaseDeployment.id}/${container.databaseContainer}')}') : 'no-dbdocument-containers-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbAccountDatabaseName: cosmosDbAccountDatabaseName
    cosmosDbAccountDatabaseContainerName: container.cosmosDatabaseContainer 
    cosmosDbAccountDatabaseContainerPartition: container.cosmosDatabaseContainerPartitionKey 
    cosmosDbAccountDatabaseContainerIndexingPolicy: container.cosmosDatabaseContainerIndexingPolicy 
    cosmosDbAccountDatabaseContainerUniqueKeyPolicies: container.cosmosDatabaseContainerUniqueKeyPolicy
    cosmosDbAccountDatabaseContainerTtl: contains(container, 'cosmosDatabaseContainerTtl') ? container.cosmosDatabaseContainerTtl : 0
  }
}]

// 3. Return Deployment Output
output resource object = azDocumentDbAccountDatabaseDeployment
