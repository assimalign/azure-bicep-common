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

@description('The Cosmos Document Db Name')
param cosmosAccountName string

@description('The Cosmos Document Db Database Name')
param cosmosAccountDatabaseName string

@description('A list of Cosmos Document Db Containers to deploy with the database')
param cosmosAccountDatabaseContainers array = []

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy the Document Database
resource cosmosAccountDocumentDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  name: formatName('${cosmosAccountName}/${cosmosAccountDatabaseName}', affix, environment, region)
  properties: {
    resource: {
      id: formatName(cosmosAccountDatabaseName, affix, environment, region)
    }
  }
}

// 2. Deploye Document DB Database Containers
module cosmosAccountDocumentDatabaseContainer 'cosmos-account-document-database-container.bicep' = [
  for container in cosmosAccountDatabaseContainers: if (!empty(container)) {
    name: !empty(cosmosAccountDatabaseContainers)
      ? toLower('az-docdb-container-${guid('${cosmosAccountDocumentDatabase.id}/${container.cosmosAccountDatabaseContainerName}')}')
      : 'no-dbdocument-containers-to-deploy'
    scope: resourceGroup()
    params: {
      affix: affix
      region: region
      environment: environment
      cosmosAccountName: cosmosAccountName
      cosmosAccountDatabaseName: cosmosAccountDatabaseName
      cosmosAccountDatabaseContainerName: container.cosmosAccountDatabaseContainerName
      cosmosAccountDatabaseContainerPartition: container.cosmosAccountDatabaseContainerPartition
      cosmosAccountDatabaseContainerIndexingPolicy: container.?cosmosAccountDatabaseContainerIndexingPolicy
      cosmosAccountDatabaseContainerUniqueKeyPolicies: container.?cosmosAccountDatabaseContainerUniqueKeyPolicies
      cosmosAccountDatabaseContainerTtl: container.?cosmosAccountDatabaseContainerTtl
    }
  }
]

// 3. Return Deployment Output
output cosmosAccountDocumentDatabase object = cosmosAccountDocumentDatabase
