@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Sql Server Instance')
param sqlServerName string

@description('A list of Sql Server Databases to deploy with the ')
param sqlServerDatabases array = []

@description('(Required) The admin username for the sql server instance')
param sqlServerAdminUsername string 

@secure()
@description('(Required) The admin password for the sql server instance')
param sqlServerAdminPassword string

@description('A flag to indeicate whether Managed System identity should be turned on')
param sqlServerEnableMsi bool = false


// 1. Deploys a Sql Server Instance
resource azSqlServerInstanceDeployment 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: replace('${sqlServerName}', '@environment', environment)
  location: resourceGroup().location
  identity: {
     type: sqlServerEnableMsi == true ? 'SystemAssigned' : 'None' 
  }
  properties: {
   administratorLogin: sqlServerAdminUsername
   administratorLoginPassword: sqlServerAdminPassword
  }
}


// 2. Deploy Sql Server Database under instance
module azSqlServerInstanceDatabaseDeployment 'az.data.sqlserver.database.bicep' = [for database in sqlServerDatabases: if(!empty(database)) {
  name: !empty(sqlServerDatabases) ? toLower('eh-namespace-policy-${guid('${azSqlServerInstanceDeployment.id}/${database.name}')}') : 'no-sql-server/no-database-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    sqlServerName: sqlServerName
    sqlServerDatabaseName: database.name
    sqlServerDatabaseSku: database.sku
  }
  dependsOn: [
    azSqlServerInstanceDeployment
  ]
}]


output resource object = azSqlServerInstanceDeployment
