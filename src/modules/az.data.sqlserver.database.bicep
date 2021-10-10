@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the sql server instance')
param sqlServerName string

@description('The pricing tier for the database instance')
param sqlServerDatabaseSku object

@description('The name of the database')
param sqlServerDatabaseName string


resource sqlServerDatabaseDeployment 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: replace('${sqlServerName}/${sqlServerDatabaseName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
      
  }
  sku: sqlServerDatabaseSku
}

output resource object = sqlServerDatabaseDeployment
