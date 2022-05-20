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

@description('The name of the Document Db Account name to deploy')
param cosmosDbAccountName string

@description('The name of the Document Db Account')
param cosmosDbAccountDatabaseName string

@description('The name of the container to deploy under the database')
param cosmosDbAccountDatabaseContainerName string

@description('The Partition Key(s) for the Document Db Container (Required)')
param cosmosDbAccountDatabaseContainerPartition object

@description('The default TTL (Time-To-Live) for each document')
param cosmosDbAccountDatabaseContainerTtl int = 0

@description('The Unique Policies for the Document Db Container. (Optional)')
param cosmosDbAccountDatabaseContainerUniqueKeyPolicies array = []

@description('A list of Indexing policies for the Database Containers. (Optional)')
param cosmosDbAccountDatabaseContainerIndexingPolicy object = {}


// 1. Deploy Document DB Container
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/graphs@2021-10-15' = {
  name: replace(replace('${cosmosDbAccountName}/${cosmosDbAccountDatabaseName}/${cosmosDbAccountDatabaseContainerName}', '@environment', environment), '@region', region)
  properties: {   
    resource: any(cosmosDbAccountDatabaseContainerTtl > 0 ? {
      defaultTtl: cosmosDbAccountDatabaseContainerTtl
      id: cosmosDbAccountDatabaseContainerName
      partitionKey: cosmosDbAccountDatabaseContainerPartition
      indexingPolicy: cosmosDbAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(cosmosDbAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: cosmosDbAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    } : {
      id: cosmosDbAccountDatabaseContainerName
      partitionKey: cosmosDbAccountDatabaseContainerPartition
      indexingPolicy: cosmosDbAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(cosmosDbAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: cosmosDbAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    })
  }
}

// 2. Return Deployment Output
output cosmosGraphDBContainer object = azDocumentDbAccountDatabaseDeployment
