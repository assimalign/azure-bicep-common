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

@description('The name of the Document Db Account name to deploy')
param cosmosAccountName string

@description('The name of the Document Db Account')
param cosmosAccountDatabaseName string

@description('The name of the container to deploy under the database')
param cosmosAccountDatabaseContainerName string

@description('The Partition Key(s) for the Document Db Container (Required)')
param cosmosAccountDatabaseContainerPartition object

@description('The default TTL (Time-To-Live) for each document')
param cosmosAccountDatabaseContainerTtl int = 0

@description('The Unique Policies for the Document Db Container. (Optional)')
param cosmosAccountDatabaseContainerUniqueKeyPolicies array = []

@description('A list of Indexing policies for the Database Containers. (Optional)')
param cosmosAccountDatabaseContainerIndexingPolicy object = {}


// 1. Deploy Document DB Container
resource cosmosAccountDocumentDatabaseContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  name: replace(replace(replace('${cosmosAccountName}/${cosmosAccountDatabaseName}/${cosmosAccountDatabaseContainerName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {   
    resource: any(cosmosAccountDatabaseContainerTtl > 0 ? {
      defaultTtl: cosmosAccountDatabaseContainerTtl
      id: cosmosAccountDatabaseContainerName
      partitionKey: cosmosAccountDatabaseContainerPartition
      indexingPolicy: cosmosAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(cosmosAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: cosmosAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    } : {
      id: cosmosAccountDatabaseContainerName
      partitionKey: cosmosAccountDatabaseContainerPartition
      indexingPolicy: cosmosAccountDatabaseContainerIndexingPolicy
      uniqueKeyPolicy: any(!empty(cosmosAccountDatabaseContainerUniqueKeyPolicies) ? {
        uniqueKeys: cosmosAccountDatabaseContainerUniqueKeyPolicies
      } : {})
    })
  }
}

// 2. Return Deployment Output
output cosmosAccountDocumentDatabaseContainer object = cosmosAccountDocumentDatabaseContainer
