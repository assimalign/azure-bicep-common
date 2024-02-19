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
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: replace(replace(sqlServerAccountName, '@environment', environment), '@region', region)
  location: sqlServerAccountLocation
  identity: {
    type: sqlServerAccountMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: contains(sqlServerAccountConfigs, 'sqlServerAccountPublicAccessEnabled') ? sqlServerAccountConfigs.sqlServerAccountPublicAccessEnabled : 'Enabled'
    restrictOutboundNetworkAccess: contains(sqlServerAccountConfigs, 'sqlServerAccountOutboundNetworkAccessEnabled') ? sqlServerAccountConfigs.sqlServerAccountOutboundNetworkAccessEnabled : 'Disabled'
    administratorLogin: sqlServerAccountAdminUsername
    administratorLoginPassword: sqlServerAccountAdminPassword
  }
  tags: union(sqlServerAccountTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
  // Add SQL Server Virtual Netowrk Rules
  resource networking 'virtualNetworkRules' = [for rule in sqlServerAccountVirtualNetworkRules: if (!empty(sqlServerAccountVirtualNetworkRules)) {
    name: replace(replace(rule.virtualNetworkRuleName, '@environment', environment), '@region', region)
    properties: {
      virtualNetworkSubnetId: any(replace(replace(resourceId(rule.virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', rule.virtualNetworkName, rule.virtualNetworkSubnetName), '@environment', environment), '@region', region))
    }
  }]
  // Add SQL Server Administrators Azure AD Group 
  resource administrators 'administrators' = if (!empty(sqlServerAccountAdministrators)) {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      sid: contains(sqlServerAccountAdministrators, environment) ? sqlServerAccountAdministrators[environment].azureAdObjectId : sqlServerAccountAdministrators.default.azureAdObjectId
      login: contains(sqlServerAccountAdministrators, environment) ? sqlServerAccountAdministrators[environment].azureAdLoginName : sqlServerAccountAdministrators.default.azureAdLoginName
      tenantId: contains(sqlServerAccountAdministrators, environment) ? sqlServerAccountAdministrators[environment].azureAdTenantId : sqlServerAccountAdministrators.default.azureAdTenantId
    }
  }
}

// 2. Deploy Sql Server Database under instance
module sqlServerDatabase 'sql-server-account-database.bicep' = [for database in sqlServerAccountDatabases: if (!empty(database)) {
  name: !empty(sqlServerAccountDatabases) ? toLower('az-sqlserver-db-${guid('${sqlServer.id}/${database.sqlServerAccountDatabaseName}')}') : 'no-sql-server/no-database-to-deploy'
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
module sqlServerPrivateEp '../private-endpoint/private-endpoint.bicep' = if (!empty(sqlServerAccountPrivateEndpoint)) {
  name: !empty(sqlServerAccountPrivateEndpoint) ? toLower('az-sqls-priv-endpoint-${guid('${sqlServer.id}/${sqlServerAccountPrivateEndpoint.privateEndpointName}')}') : 'no-sql-private-endpoint-to-deploy'
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
    privateEndpointResourceIdLink: sqlServer.id
    privateEndpointTags: contains(sqlServerAccountPrivateEndpoint, 'privateEndpointTags') ? sqlServerAccountPrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'sqlServer'
    ]
  }
}

output sqlServer object = sqlServer
