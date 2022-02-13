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

@description('The name of the sql server instance')
param sqlServerName string

@description('')
param sqlServerDatabaseLocation string = resourceGroup().location

@description('The pricing tier for the database instance')
param sqlServerDatabaseSku object

@description('The name of the database')
param sqlServerDatabaseName string


resource sqlServerDatabaseDeployment 'Microsoft.Sql/servers/databases@2021-08-01-preview' = {
  name: replace(replace('${sqlServerName}/${sqlServerDatabaseName}', '@environment', environment), '@region', region)
  location: sqlServerDatabaseLocation
  properties: {
      
  }
  sku: sqlServerDatabaseSku
}

output resource object = sqlServerDatabaseDeployment
