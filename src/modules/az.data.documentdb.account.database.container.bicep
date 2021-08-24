@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Document Db Account name to deploy')
param dbAccountName string

@description('The name of the Document Db Account')
param dbAccountDatabaseName string

@description('The name of the container to deploy under the database')
param dbAccountDatabaseContainerName string

@description('The Partition Key(s) for the Document Db Container (Required)')
param dbAccountDatabaseContainerPartition object

@description('The Unique Policies for the Document Db Container. (Optional)')
param dbAccountDatabaseContainerUniqueKeyPolicies array = []

@description('A list of Indexing policies for the Database Containers. (Optional)')
param dbAccountDatabaseContainerIndexingPolicy object = {}



resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  name: replace('${dbAccountName}/${dbAccountDatabaseName}/${dbAccountDatabaseContainerName}', '@environment', environment)
  properties: {
    resource: {
      id: dbAccountDatabaseContainerName
      partitionKey: dbAccountDatabaseContainerPartition
      indexingPolicy: dbAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(dbAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: dbAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    }
  }
}

output resource object = azDocumentDbAccountDatabaseDeployment
