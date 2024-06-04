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

@description('The name of the Database Account for the storage table')
param cosmosAccountName string

@description('The name of the table to deploy')
param cosmosAccountTableName string

resource cosmosAccountTableDatabase 'Microsoft.DocumentDB/databaseAccounts/tables@2023-11-15' = {
  name: replace(replace(replace('${cosmosAccountName}/${cosmosAccountTableName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    resource: {
      id: cosmosAccountTableName
    }
  }
}

output cosmosAccountTableDatabase object = cosmosAccountTableDatabase
