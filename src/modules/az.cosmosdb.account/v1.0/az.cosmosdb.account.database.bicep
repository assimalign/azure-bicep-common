@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The Cosmos Document Db Name')
param cosmosDbAccountName string

@description('The Cosmos Document Db Database Name')
param cosmosDbAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param cosmosDbAccountDatabaseContainers array = []


// 1. Deploy the Document Database
resource azDocumentDbAccountDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: replace(replace('${cosmosDbAccountName}/${cosmosDbAccountDatabaseName}', '@environment', environment), '@region', region)
  properties: {
    resource: {
      id: replace(replace(cosmosDbAccountDatabaseName, '@environment', environment), '@region', region)
    }
  }
}

// 2. Deploye Document DB Database Containers
module azDocumentDbAccountDatabaseContainerDeployment 'az.cosmosdb.account.database.container.bicep' = [for container in cosmosDbAccountDatabaseContainers: if(!empty(container)) {
  name: !empty(cosmosDbAccountDatabaseContainers) ? toLower('az-docdb-container-${guid('${azDocumentDbAccountDatabaseDeployment.id}/${container.databaseContainer}')}') : 'no-dbdocument-containers-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
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
