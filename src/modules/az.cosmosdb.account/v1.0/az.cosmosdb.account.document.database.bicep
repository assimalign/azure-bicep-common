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

@description('The Cosmos Document Db Name')
param cosmosAccountName string

@description('The Cosmos Document Db Database Name')
param cosmosAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param cosmosAccountDatabaseContainers array = []


// 1. Deploy the Document Database
resource azCosmosAccountDocumentDatabaseDeployment 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-08-15'= {
  name: replace(replace('${cosmosAccountName}/${cosmosAccountDatabaseName}', '@environment', environment), '@region', region)
  properties: {
    resource: {
      id: replace(replace(cosmosAccountDatabaseName, '@environment', environment), '@region', region)
    }
  }
}

// 2. Deploye Document DB Database Containers
module azCosmosAccountDocumentDatabaseContainerDeployment 'az.cosmosdb.account.document.database.container.bicep' = [for container in cosmosAccountDatabaseContainers: if(!empty(container)) {
  name: !empty(cosmosAccountDatabaseContainers) ? toLower('az-docdb-container-${guid('${azCosmosAccountDocumentDatabaseDeployment.id}/${container.cosmosAccountDatabaseContainerName}')}') : 'no-dbdocument-containers-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    cosmosAccountName: cosmosAccountName
    cosmosAccountDatabaseName: cosmosAccountDatabaseName
    cosmosAccountDatabaseContainerName: container.cosmosAccountDatabaseContainerName 
    cosmosAccountDatabaseContainerPartition: container.cosmosAccountDatabaseContainerPartition 
    cosmosAccountDatabaseContainerIndexingPolicy: contains(container, 'cosmosAccountDatabaseContainerIndexingPolicy') ? container.cosmosAccountDatabaseContainerIndexingPolicy : {}
    cosmosAccountDatabaseContainerUniqueKeyPolicies: contains(container, 'cosmosAccountDatabaseContainerUniqueKeyPolicies') ? container.cosmosAccountDatabaseContainerUniqueKeyPolicies : []
    cosmosAccountDatabaseContainerTtl: contains(container, 'cosmosAccountDatabaseContainerTtl') ? container.cosmosAccountDatabaseContainerTtl : 0
  }
}]

// 3. Return Deployment Output
output cosmosAccountDocumentDatabase object = azCosmosAccountDocumentDatabaseDeployment
