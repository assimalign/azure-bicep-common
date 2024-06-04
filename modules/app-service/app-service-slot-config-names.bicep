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

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The Function App Name to be deployed')
param appName string

@description('')
param appSlotSettingNames array = []

@description('')
param appSlotConnectionStringNames array = []

@description('')
param appSlotAzureStorageConfigNames array = []

resource appServiceSlotConfigName 'Microsoft.Web/sites/config@2023-01-01' = {
  name: replace(replace(replace('${appName}/slotConfigNames', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    appSettingNames: appSlotSettingNames
    connectionStringNames: appSlotConnectionStringNames
    azureStorageConfigNames: appSlotAzureStorageConfigNames
  }
}

output appServiceSlotConfigName object = appServiceSlotConfigName
