@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The Cosmos Document Db Name')
param dbAccountName string

@description('The Cosmos Document Db Database Name')
param dbAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param dbAccountDatabaseContainers array = []


// 1. Deploy the Document Database
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: replace('${dbAccountName}/${dbAccountDatabaseName}', '@environment', environment)
  properties: {
    resource: {
      id: replace(dbAccountDatabaseName, '@environment', environment)
    }
  }
}


module azDocumentDbAccountDatabaseContainerDeployment 'az.data.documentdb.account.database.container.bicep' = [for container in dbAccountDatabaseContainers: if(!empty(container)) {
  name: !empty(dbAccountDatabaseContainers) ? toLower('az-documentdb-container-${guid('${azDocumentDbAccountDatabaseDeployment.id}/${container.name}')}') : 'no-dbdocument-containers-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    dbAccountName: dbAccountName
    dbAccountDatabaseName: dbAccountDatabaseName
    dbAccountDatabaseContainerName: container.name 
    dbAccountDatabaseContainerPartition: container.partitionKey 
    dbAccountDatabaseContainerIndexingPolicy: container.indexingPolicy 
    dbAccountDatabaseContainerUniqueKeyPolicies: container.uniqueKeyPolicy
  }
  dependsOn: [
    azDocumentDbAccountDatabaseDeployment
  ]
}]


output resource object = azDocumentDbAccountDatabaseDeployment
