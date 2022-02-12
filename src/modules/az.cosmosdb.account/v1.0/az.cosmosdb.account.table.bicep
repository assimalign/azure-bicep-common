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
param cosmosDbAccountName string

@description('The name of the table to deploy')
param cosmosDbAccountTableName string



resource azDocumentDbAccountDatabaseTableDeployment 'Microsoft.DocumentDB/databaseAccounts/tables@2021-06-15' = {
  name: replace(replace('${cosmosDbAccountName}/${cosmosDbAccountTableName}', '@environment', environment), '@region', region)
  properties: {
    resource: {
      id: cosmosDbAccountTableName
    }
  }
}


output resource object = azDocumentDbAccountDatabaseTableDeployment
