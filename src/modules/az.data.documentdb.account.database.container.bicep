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

@description('The name of the Document Db Account name to deploy')
param dbAccountName string

@description('The name of the Document Db Account')
param dbAccountDatabaseName string

@description('The name of the container to deploy under the database')
param dbAccountDatabaseContainerName string

@description('The Partition Key(s) for the Document Db Container (Required)')
param dbAccountDatabaseContainerPartition object

@description('The default TTL (Time-To-Live) for each document')
param dbAccountDatabaseContainerTtl int = 0

@description('The Unique Policies for the Document Db Container. (Optional)')
param dbAccountDatabaseContainerUniqueKeyPolicies array = []

@description('A list of Indexing policies for the Database Containers. (Optional)')
param dbAccountDatabaseContainerIndexingPolicy object = {}


// 1. Deploy Document DB Container
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  name: replace(replace('${dbAccountName}/${dbAccountDatabaseName}/${dbAccountDatabaseContainerName}', '@environment', environment), '@location', location)
  properties: {    
    resource: any(dbAccountDatabaseContainerTtl > 0 ? {
      defaultTtl: dbAccountDatabaseContainerTtl
      id: dbAccountDatabaseContainerName
      partitionKey: dbAccountDatabaseContainerPartition
      indexingPolicy: dbAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(dbAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: dbAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    } : {
      id: dbAccountDatabaseContainerName
      partitionKey: dbAccountDatabaseContainerPartition
      indexingPolicy: dbAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(dbAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: dbAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    })
  }
}

// 2. Return Deployment Output
output resource object = azDocumentDbAccountDatabaseDeployment
