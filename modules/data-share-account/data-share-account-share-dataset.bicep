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

@description('The name of the Azure Data Share Service to be deployed.')
param dataShareName string

@description('The name of the Azure Data Share Service to be deployed.')
param dataShareAccountName string

@description('')
param dataShareDatasetName string

@description('')
param dataShareDatasetConfigs object

@allowed([
  'AdlsGen1File'
  'AdlsGen1Folder'
  'AdlsGen2File'
  'AdlsGen2Folder'
  'Blob'
  'Container'
])
@description('')
param dataShareDatasetType string

var subscriptionId = az.subscription().subscriptionId

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var properties = any(dataShareDatasetType == 'AdlsGen1File' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  fileName: formatName(dataShareDatasetConfigs.datasetFileName, affix, environment, region)
  folderPath: formatName(dataShareDatasetConfigs.datasetFolderPath, affix, environment, region)
  accountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
} : any(dataShareDatasetType == 'AdlsGen1Folder' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  folderPath: formatName(dataShareDatasetConfigs.datasetFolderPath, affix, environment, region)
  accountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
} : any(dataShareDatasetType == 'AdlsGen2File' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  filePath: formatName(dataShareDatasetConfigs.datasetFilePath, affix, environment, region)
  fileSystem: formatName(dataShareDatasetConfigs.datasetFileSystem, affix, environment, region)
  storageAccountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
} : any(dataShareDatasetType == 'AdlsGen2Folder' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  filePath: formatName(dataShareDatasetConfigs.datasetFilePath, affix, environment, region)
  fileSystem: formatName(dataShareDatasetConfigs.datasetFileSystem, affix, environment, region)
  folderPath: formatName(dataShareDatasetConfigs.datasetFolderPath, affix, environment, region)
  storageAccountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
} : any(dataShareDatasetType == 'Blob' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  filePath: formatName(dataShareDatasetConfigs.datasetBlobPath, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  storageAccountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
  containerName: formatName(dataShareDatasetConfigs.datasetContainerName, affix, environment, region)
} : any(dataShareDatasetType == 'Container' ? {
  resourceGroup: formatName(dataShareDatasetConfigs.datasetResourceGroup, affix, environment, region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  storageAccountName: formatName(dataShareDatasetConfigs.datasetAccountName, affix, environment, region)
  containerName: formatName(dataShareDatasetConfigs.datasetContainerName, affix, environment, region)
} : {}))))))

resource azDataShareAccountDataSetDeployment 'Microsoft.DataShare/accounts/shares/dataSets@2021-08-01' = {
  name: formatName('${dataShareAccountName}/${dataShareName}/${dataShareDatasetName}', affix, environment, region)
  kind: dataShareDatasetType
  properties: properties
}


output dataShareDataset object = azDataShareAccountDataSetDeployment
