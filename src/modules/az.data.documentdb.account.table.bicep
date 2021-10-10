@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Database Account for the storage table')
param dbAccountName string

@description('The name of the table to deploy')
param dbAccountTableName string




resource azDocumentDbAccountDatabaseTableDeployment 'Microsoft.DocumentDB/databaseAccounts/tables@2021-06-15' = {
  name: replace('${dbAccountName}/${dbAccountTableName}', '@environment', environment)
  properties: {
    resource: {
      id: dbAccountTableName
    }
  }
}


output resource object = azDocumentDbAccountDatabaseTableDeployment
