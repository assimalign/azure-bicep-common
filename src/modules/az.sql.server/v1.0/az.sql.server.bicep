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

@description('The name of the Sql Server Instance')
param sqlServerAccountName string

@description('')
param sqlServerAccountLocation string = resourceGroup().location

@description('')
param sqlServerAccountConfigs object = {}

@description('')
param sqlServerAccountAdministrators object = {}

@description('A list of Sql Server Databases to deploy with the ')
param sqlServerAccountDatabases array = []

@description('(Required) The admin username for the sql server instance')
param sqlServerAccountAdminUsername string

@secure()
@description('(Required) The admin password for the sql server instance')
param sqlServerAccountAdminPassword string

@description('A flag to indeicate whether Managed System identity should be turned on')
param sqlServerAccountMsiEnabled bool = false

@description('')
param sqlServerAccountVirtualNetworkRules array = []

@description('')
param sqlServerAccountPrivateEndpoint object = {}

@description('')
param sqlServerAccountTags object = {}


// 1. Deploys a Sql Server Instance
resource azSqlServerInstanceDeployment 'Microsoft.Sql/servers@2021-08-01-preview' = {
  name: replace(replace(sqlServerAccountName, '@environment', environment), '@region', region)
  location: sqlServerAccountLocation
  identity: {
    type: sqlServerAccountMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    minimalTlsVersion: '1.2'
    administrators: empty(sqlServerAccountAdministrators) ? json('null') : any(environment == 'dev' ? {
      sid: sqlServerAccountAdministrators.dev.azureAdObjectId
      principalType: sqlServerAccountAdministrators.dev.azureAdObjectType
      tenantId: sqlServerAccountAdministrators.dev.azureAdTenantId
      azureADOnlyAuthentication: sqlServerAccountAdministrators.dev.azureAdAuthenticationOnly
    } : any(environment == 'qa' ? {
      sid: sqlServerAccountAdministrators.qa.azureAdObjectId
      principalType: sqlServerAccountAdministrators.qa.azureAdObjectType
      tenantId: sqlServerAccountAdministrators.qa.azureAdTenantId
      azureADOnlyAuthentication: sqlServerAccountAdministrators.qa.azureAdAuthenticationOnly
    } : any(environment == 'uat' ? {
      sid: sqlServerAccountAdministrators.uat.azureAdObjectId
      principalType: sqlServerAccountAdministrators.uat.azureAdObjectType
      tenantId: sqlServerAccountAdministrators.uat.azureAdTenantId
      azureADOnlyAuthentication: sqlServerAccountAdministrators.uat.azureAdAuthenticationOnly
    } : any(environment == 'prd' ? {
      sid: sqlServerAccountAdministrators.prd.azureAdObjectId
      principalType: sqlServerAccountAdministrators.prd.azureAdObjectType
      tenantId: sqlServerAccountAdministrators.prd.azureAdTenantId
      azureADOnlyAuthentication: sqlServerAccountAdministrators.prd.azureAdAuthenticationOnly
    } : {}))))
    publicNetworkAccess: contains(sqlServerAccountConfigs, 'sqlServerAccountPublicAccessEnabled') ? sqlServerAccountConfigs.sqlServerAccountPublicAccessEnabled : 'Enabled'
    restrictOutboundNetworkAccess: contains(sqlServerAccountConfigs, 'sqlServerAccountOutboundNetworkAccessEnabled') ? sqlServerAccountConfigs.sqlServerAccountOutboundNetworkAccessEnabled : 'Disabled'
    administratorLogin: sqlServerAccountAdminUsername
    administratorLoginPassword: sqlServerAccountAdminPassword
  }
  tags: union(sqlServerAccountTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
  resource networking 'virtualNetworkRules' = [for rule in sqlServerAccountVirtualNetworkRules: if (!empty(sqlServerAccountVirtualNetworkRules)){
    name: replace(replace(rule.virtualNetworkRuleName, '@environment', environment), '@region', region)
    properties: {
      virtualNetworkSubnetId: resourceId(subscription().subscriptionId, replace(replace(rule.virtualNetworkResourceGroup, '@environment', environment), '@region', region),'Microsoft.Network/virtualNetworks', replace(replace('${rule.virtualNetworkName}/subnets/${rule.virtualNetworkSubnetName}', '@environment', environment), '@region', region))
    }
  }]
}

// 2. Deploy Sql Server Database under instance
module azSqlServerInstanceDatabaseDeployment 'az.sql.server.database.bicep' = [for database in sqlServerAccountDatabases: if (!empty(database)) {
  name: !empty(sqlServerAccountDatabases) ? toLower('az-sqlserver-db-${guid('${azSqlServerInstanceDeployment.id}/${database.sqlServerAccountDatabaseName}')}') : 'no-sql-server/no-database-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    sqlServerAccountName: sqlServerAccountName
    sqlServerAccountDatabaseLocation: sqlServerAccountLocation
    sqlServerAccountDatabaseName: database.sqlServerAccountDatabaseName
    sqlServerAccountDatabaseSku: database.sqlServerAccountDatabaseSku
    sqlServerAccountDatabaseTags: contains(database, 'sqlServerAccountDatabaseTags') ? database.sqlServerAccountDatabaseTags : {}
    sqlServerAccountDatabaseConfigs: contains(database, 'sqlServerAccountDatabaseConfigs') ? database.sqlServerAccountDatabaseConfigs : {}
  }
}]


// 4. Deploy Private Endpoint if applicable
module azEventGridPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(sqlServerAccountPrivateEndpoint)) {
  name: !empty(sqlServerAccountPrivateEndpoint) ? toLower('az-sqls-priv-endpoint-${guid('${azSqlServerInstanceDeployment.id}/${sqlServerAccountPrivateEndpoint.privateEndpointName}')}') : 'no-egd-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointLocation: contains(sqlServerAccountPrivateEndpoint, 'privateEndpointLocation') ? sqlServerAccountPrivateEndpoint.privateEndpointLocation : sqlServerAccountLocation
    privateEndpointName: sqlServerAccountPrivateEndpoint.privateEndpointName
    privateEndpointDnsZoneGroupName: 'privatelink-database-windows-net'
    privateEndpointDnsZoneName: sqlServerAccountPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneResourceGroup: sqlServerAccountPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azSqlServerInstanceDeployment.id
    privateEndpointTags: contains(sqlServerAccountPrivateEndpoint, 'privateEndpointTags') ? sqlServerAccountPrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'sqlServer'
    ]
  }
}

output resource object = azSqlServerInstanceDeployment

// Publish-AzBicepModule -FilePath './src/modules/az.sql.server/v1.0/az.sql.server.bicep' -Target 'br:asalbicep.azurecr.io/modules/az.sql.server:v1.0'
