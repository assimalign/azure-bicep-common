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

@description('The name of the Sql Server Instance')
param sqlServerAccountName string

@description('')
param sqlServerAccountLocation string = resourceGroup().location

@description('')
param sqlServerAccountAdministrators object = {}

@description('A list of Sql Server Databases to deploy with the ')
param sqlServerAccountDatabases array = []

@description('(Required) The admin username for the sql server instance')
param sqlServerAccountAdminUsername string

@secure()
@description('(Required) The admin password for the sql server instance')
param sqlServerAccountAdminPassword string

@description('')
param sqlServerAccountNetworkSettings object = {}

@description('A flag to indeicate whether Managed System identity should be turned on')
param sqlServerAccountMsiEnabled bool = false

@description('')
param sqlServerAccountMsiRoleAssignments array = []

@description('')
param sqlServerAccountPrivateEndpoint object = {}

@description('')
param sqlServerAccountTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var allowAzureResources = sqlServerAccountNetworkSettings.?allowAzureServices ?? 'Disabled'
var allowPublicNetworkAccess = sqlServerAccountNetworkSettings.?allowPublicNetworkAccess ?? 'Enabled'
var firewallRules = allowAzureResources == 'Enabled' && allowPublicNetworkAccess == 'Enabled'
  ? union(
      [
        {
          ruleName: 'AllowAllWindowsAzureIps'
          ruleStartIp: '0.0.0.0'
          ruleEndIp: '0.0.0.0'
        }
      ],
      sqlServerAccountNetworkSettings.?firewallRules ?? []
    )
  : sqlServerAccountNetworkSettings.?firewallRules ?? []

// 1. Deploys a Sql Server Instance
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: formatName(sqlServerAccountName, affix, environment, region)
  location: sqlServerAccountLocation
  identity: {
    type: sqlServerAccountMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: allowPublicNetworkAccess
    restrictOutboundNetworkAccess: sqlServerAccountNetworkSettings.?allowOutboundNetworkAccess ?? 'Disabled'
    administratorLogin: sqlServerAccountAdminUsername
    administratorLoginPassword: sqlServerAccountAdminPassword
  }
  tags: union(sqlServerAccountTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
  resource firewall 'firewallRules' = [
    for rule in firewallRules: {
      name: rule.ruleName
      properties: {
        startIpAddress: rule.ruleStartIp
        endIpAddress: rule.ruleEndIp
      }
    }
  ]
  // Add SQL Server Virtual Netowrk Rules
  resource networking 'virtualNetworkRules' = [
    for rule in sqlServerAccountNetworkSettings.?virtualNetworkRules ?? []: {
      name: formatName(rule.virtualNetworkRuleName, affix, environment, region)
      properties: {
        virtualNetworkSubnetId: resourceId(
          formatName(rule.virtualNetworkResourceGroup, affix, environment, region),
          'Microsoft.Network/virtualNetworks/subnets',
          formatName(rule.virtualNetworkName, affix, environment, region),
          formatName(rule.virtualNetworkSubnetName, affix, environment, region)
        )
      }
    }
  ]
  // Add SQL Server Administrators Azure AD Group 
  resource administrators 'administrators' = if (!empty(sqlServerAccountAdministrators)) {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      sid: contains(sqlServerAccountAdministrators, environment)
        ? sqlServerAccountAdministrators[environment].azureAdObjectId
        : sqlServerAccountAdministrators.default.azureAdObjectId
      login: contains(sqlServerAccountAdministrators, environment)
        ? sqlServerAccountAdministrators[environment].azureAdLoginName
        : sqlServerAccountAdministrators.default.azureAdLoginName
      tenantId: contains(sqlServerAccountAdministrators, environment)
        ? sqlServerAccountAdministrators[environment].azureAdTenantId
        : sqlServerAccountAdministrators.default.azureAdTenantId
    }
  }
}

// 2. Deploy Sql Server Database under instance
module sqlServerDatabase 'sql-server-account-database.bicep' = [
  for database in sqlServerAccountDatabases: if (!empty(database)) {
    name: !empty(sqlServerAccountDatabases)
      ? toLower('az-sqlserver-db-${guid('${sqlServer.id}/${database.sqlServerAccountDatabaseName}')}')
      : 'no-sql-server/no-database-to-deploy'
    params: {
      affix: affix
      region: region
      environment: environment
      sqlServerAccountName: sqlServerAccountName
      sqlServerAccountDatabaseLocation: sqlServerAccountLocation
      sqlServerAccountDatabaseName: database.sqlServerAccountDatabaseName
      sqlServerAccountDatabaseSku: database.sqlServerAccountDatabaseSku
      sqlServerAccountDatabaseTags: database.?sqlServerAccountDatabaseTags
      sqlServerAccountDatabaseConfigs: database.?sqlServerAccountDatabaseConfigs
    }
  }
]

module rbac '../rbac/rbac.bicep' = [
  for sqlRoleAssignment in sqlServerAccountMsiRoleAssignments: if (sqlServerAccountMsiEnabled == true && !empty(sqlServerAccountMsiRoleAssignments)) {
    name: 'app-rbac-${guid('${sqlServer.name}-${sqlRoleAssignment.resourceRoleName}')}'
    scope: resourceGroup(formatName(sqlRoleAssignment.resourceGroupToScopeRoleAssignment, affix,environment, region))
    params: {
      affix: affix
      region: region
      environment: environment
      resourceRoleName: sqlRoleAssignment.resourceRoleName
      resourceToScopeRoleAssignment: sqlRoleAssignment.resourceToScopeRoleAssignment
      resourceGroupToScopeRoleAssignment: sqlRoleAssignment.resourceGroupToScopeRoleAssignment
      resourceRoleAssignmentScope: sqlRoleAssignment.resourceRoleAssignmentScope
      resourceTypeAssigningRole: sqlRoleAssignment.resourceTypeAssigningRole
      resourcePrincipalIdReceivingRole: sqlServer.identity.principalId
    }
  }
]
// 4. Deploy Private Endpoint if applicable
module sqlServerPrivateEp '../private-endpoint/private-endpoint.bicep' = if (!empty(sqlServerAccountPrivateEndpoint)) {
  name: !empty(sqlServerAccountPrivateEndpoint)
    ? toLower('az-sqls-priv-endpoint-${guid('${sqlServer.id}/${sqlServerAccountPrivateEndpoint.privateEndpointName}')}')
    : 'no-sql-private-endpoint-to-deploy'
  params: {
    affix: affix
    region: region
    environment: environment
    privateEndpointLocation: sqlServerAccountPrivateEndpoint.?privateEndpointLocation ?? sqlServerAccountLocation
    privateEndpointName: sqlServerAccountPrivateEndpoint.privateEndpointName
    privateEndpointDnsZoneGroupConfigs: sqlServerAccountPrivateEndpoint.privateEndpointDnsZoneGroupConfigs
    privateEndpointVirtualNetworkName: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: sqlServerAccountPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: sqlServer.id
    privateEndpointTags: sqlServerAccountPrivateEndpoint.privateEndpointTags
    privateEndpointGroupIds: [
      'sqlServer'
    ]
  }
}

output sqlServer object = sqlServer
