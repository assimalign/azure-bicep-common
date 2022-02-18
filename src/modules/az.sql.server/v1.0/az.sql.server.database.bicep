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

var properties = any(environment == 'dev' ? {
  minCapacity: contains(sqlServerAccountDatabaseSku.dev, 'dbMinCapacity') ? sqlServerAccountDatabaseSku.dev.dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku.dev, 'dbRedundancy') ? sqlServerAccountDatabaseSku.dev.dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku.dev.dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku.dev.dbMaxGBSize * 1073741824
} : any(environment == 'qa' ? {
  minCapacity: contains(sqlServerAccountDatabaseSku.dev, 'dbMinCapacity') ? sqlServerAccountDatabaseSku.dev.dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku.qa, 'dbRedundancy') ? sqlServerAccountDatabaseSku.qa.dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku.qa.dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku.qa.dbMaxGBSize * 1073741824
} : any(environment == 'uat' ? {
  minCapacity: contains(sqlServerAccountDatabaseSku.dev, 'dbMinCapacity') ? sqlServerAccountDatabaseSku.dev.dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku.uat, 'dbRedundancy') ? sqlServerAccountDatabaseSku.uat.dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku.uat.dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku.uat.dbMaxGBSize * 1073741824
} : any(environment == 'prd' ? {
  minCapacity: contains(sqlServerAccountDatabaseSku.dev, 'dbMinCapacity') ? sqlServerAccountDatabaseSku.dev.dbMinCapacity : 1
  requestedBackupStorageRedundancy: contains(sqlServerAccountDatabaseSku.prd, 'dbRedundancy') ? sqlServerAccountDatabaseSku.prd.dbRedundancy : 'Local'
  readScale: sqlServerAccountDatabaseSku.prd.dbTier == 'Preimum' && contains(sqlServerAccountDatabaseConfigs, 'dbReadScale') ? sqlServerAccountDatabaseConfigs.dbReadScale : 'Disabled'
  maxSizeBytes: sqlServerAccountDatabaseSku.prd.dbMaxGBSize * 1073741824
} : {}))))

resource sqlServerDatabaseDeployment 'Microsoft.Sql/servers/databases@2021-08-01-preview' = {
  name: replace(replace('${sqlServerAccountName}/${sqlServerAccountDatabaseName}', '@environment', environment), '@region', region)
  location: sqlServerAccountDatabaseLocation
  properties: union({
      collation: contains(sqlServerAccountDatabaseConfigs, 'dbCollation') ? sqlServerAccountDatabaseConfigs.dbCollation : 'SQL_Latin1_General_CP1_CI_AS'
  }, properties)
    
  sku: any(environment == 'dev' ? {
    tier: sqlServerAccountDatabaseSku.dev.dbTier
    name: sqlServerAccountDatabaseSku.dev.dbTier
    capacity: sqlServerAccountDatabaseSku.dev.dbMaxCapacity
  } : any(environment == 'qa' ? {
    tier: sqlServerAccountDatabaseSku.qa.dbTier
    name: sqlServerAccountDatabaseSku.qa.dbTier
    capacity: sqlServerAccountDatabaseSku.qa.dbMaxCapacity
  } : any(environment == 'uat' ? {
    tier: sqlServerAccountDatabaseSku.uat.dbTier
    name: sqlServerAccountDatabaseSku.uat.dbTier
    capacity: sqlServerAccountDatabaseSku.uat.dbMaxCapacity
  } : any(environment == 'prd' ? {
    tier: sqlServerAccountDatabaseSku.prd.dbTier
    name: sqlServerAccountDatabaseSku.prd.dbTier
    capacity: sqlServerAccountDatabaseSku.prd.dbMaxCapacity
  } : {}))))
  tags: sqlServerAccountDatabaseTags
}

output resource object = sqlServerDatabaseDeployment


// Publish-AzBicepModule -FilePath './src/modules/az.sql.server/v1.0/az.sql.server.database.bicep' -Target 'br:asalbicep.azurecr.io/modules/az.sql.server.database:v1.0'
