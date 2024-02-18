@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('The Function App Name to be deployed')
param appName string

@description('')
param appSlotSettingNames array = []

@description('')
param appSlotConnectionStringNames array = []

@description('')
param appSlotAzureStorageConfigNames array = []

resource azAppServiceSlotSpecificSettingDeployment 'Microsoft.Web/sites/config@2023-01-01' = {
  name: replace(replace('${appName}/slotConfigNames', '@environment', environment), '@region', region)
  properties: {
    appSettingNames: appSlotSettingNames
    connectionStringNames: appSlotConnectionStringNames
    azureStorageConfigNames: appSlotAzureStorageConfigNames
  }
}
