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
param dbAccountName string

@description('The Cosmos Document Db Database Name')
param dbAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param dbAccountDatabaseContainers array = []


// 1. Deploy the Document Database
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: replace(replace('${dbAccountName}/${dbAccountDatabaseName}', '@environment', environment), '@location', location)
  properties: {
    resource: {
      id: replace(replace(dbAccountDatabaseName, '@environment', environment), '@location', location)
    }
  }
}

// 2. Deploye Document DB Database Containers
module azDocumentDbAccountDatabaseContainerDeployment 'az.data.documentdb.account.database.container.bicep' = [for container in dbAccountDatabaseContainers: if(!empty(container)) {
  name: !empty(dbAccountDatabaseContainers) ? toLower('az-docdb-container-${guid('${azDocumentDbAccountDatabaseDeployment.id}/${container.databaseContainer}')}') : 'no-dbdocument-containers-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    dbAccountName: dbAccountName
    dbAccountDatabaseName: dbAccountDatabaseName
    dbAccountDatabaseContainerName: container.databaseContainer 
    dbAccountDatabaseContainerPartition: container.databaseContainerPartitionKey 
    dbAccountDatabaseContainerIndexingPolicy: container.databaseContainerIndexingPolicy 
    dbAccountDatabaseContainerUniqueKeyPolicies: container.databaseContainerUniqueKeyPolicy
  }
  dependsOn: [
    azDocumentDbAccountDatabaseDeployment
  ]
}]

// 3. Return Deployment Output
output resource object = azDocumentDbAccountDatabaseDeployment
