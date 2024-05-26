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

@description('The name of the sql server instance')
param sqlServerAccountName string

@description('The name of the database')
param sqlServerAccountDatabaseName string

@description('')
param sqlServerAccountDatabaseLocation string = resourceGroup().location

@description('The pricing tier for the database instance')
param sqlServerAccountDatabaseSku object

@description('')
param sqlServerAccountDatabaseConfigs object = {}

@description('')
param sqlServerAccountDatabaseTags object = {}

var properties = any(contains(sqlServerAccountDatabaseSku, environment) ? {
  minCapacity: contains(sqlServerAccountDatabaseSku[environment], 'dbMinCapacity') ? sqlServerAccountDatabaseSku[environment].dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku[environment], 'dbRedundancy') ? sqlServerAccountDatabaseSku[environment].dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku[environment].dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku[environment].dbMaxGBSize * 1073741824
} : {
  minCapacity: contains(sqlServerAccountDatabaseSku.default, 'dbMinCapacity') ? sqlServerAccountDatabaseSku.default.dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku.default, 'dbRedundancy') ? sqlServerAccountDatabaseSku.default.dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku.default.dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku.default.dbMaxGBSize * 1073741824
})

resource sqlServerDatabaseDeployment 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: replace(replace('${sqlServerAccountName}/${sqlServerAccountDatabaseName}', '@environment', environment), '@region', region)
  location: sqlServerAccountDatabaseLocation
  properties: union({
      collation: contains(sqlServerAccountDatabaseConfigs, 'dbCollation') ? sqlServerAccountDatabaseConfigs.dbCollation : 'SQL_Latin1_General_CP1_CI_AS'
    }, properties)
  sku: any(contains(sqlServerAccountDatabaseSku, environment) ? {
    tier: sqlServerAccountDatabaseSku[environment].dbTier
    name: sqlServerAccountDatabaseSku[environment].dbTier
    capacity: sqlServerAccountDatabaseSku[environment].dbMaxCapacity
  } : {
    tier: sqlServerAccountDatabaseSku.default.dbTier
    name: sqlServerAccountDatabaseSku.default.dbTier
    capacity: sqlServerAccountDatabaseSku.default.dbMaxCapacity
  })
  tags: union(sqlServerAccountDatabaseTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output sqlServerDatabase object = sqlServerDatabaseDeployment
