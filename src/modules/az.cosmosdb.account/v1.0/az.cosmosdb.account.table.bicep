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

@description('The name of the Database Account for the storage table')
param cosmosAccountName string

@description('The name of the table to deploy')
param cosmosAccountTableName string

resource azDocumentDbAccountDatabaseTableDeployment 'Microsoft.DocumentDB/databaseAccounts/tables@2021-06-15' = {
  name: replace(replace('${cosmosAccountName}/${cosmosAccountTableName}', '@environment', environment), '@region', region)
  properties: {
    resource: {
      id: cosmosAccountTableName
    }
  }
}

output cosmosAccountTableDatabase object = azDocumentDbAccountDatabaseTableDeployment
