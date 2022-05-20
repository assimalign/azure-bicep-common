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

var properties = any(dataShareDatasetType == 'AdlsGen1File' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  fileName: replace(replace(dataShareDatasetConfigs.datasetFileName, '@environment', environment), '@region', region)
  folderPath: replace(replace(dataShareDatasetConfigs.datasetFolderPath, '@environment', environment), '@region', region)
  accountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
} : any(dataShareDatasetType == 'AdlsGen1Folder' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  folderPath: replace(replace(dataShareDatasetConfigs.datasetFolderPath, '@environment', environment), '@region', region)
  accountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
} : any(dataShareDatasetType == 'AdlsGen2File' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  filePath: replace(replace(dataShareDatasetConfigs.datasetFilePath, '@environment', environment), '@region', region)
  fileSystem: replace(replace(dataShareDatasetConfigs.datasetFileSystem, '@environment', environment), '@region', region)
  storageAccountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
} : any(dataShareDatasetType == 'AdlsGen2Folder' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  filePath: replace(replace(dataShareDatasetConfigs.datasetFilePath, '@environment', environment), '@region', region)
  fileSystem: replace(replace(dataShareDatasetConfigs.datasetFileSystem, '@environment', environment), '@region', region)
  folderPath: replace(replace(dataShareDatasetConfigs.datasetFolderPath, '@environment', environment), '@region', region)
  storageAccountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
} : any(dataShareDatasetType == 'Blob' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  filePath: replace(replace(dataShareDatasetConfigs.datasetBlobPath, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  storageAccountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
  containerName: replace(replace(dataShareDatasetConfigs.datasetContainerName, '@environment', environment), '@region', region)
} : any(dataShareDatasetType == 'Container' ? {
  resourceGroup: replace(replace(dataShareDatasetConfigs.datasetResourceGroup, '@environment', environment), '@region', region)
  subscriptionId: contains(dataShareDatasetConfigs, 'datasetSubscriptionId') ? replace(dataShareDatasetConfigs.datasetResourceGroup, '@subscription', subscriptionId) : subscriptionId
  storageAccountName: replace(replace(dataShareDatasetConfigs.datasetAccountName, '@environment', environment), '@region', region)
  containerName: replace(replace(dataShareDatasetConfigs.datasetContainerName, '@environment', environment), '@region', region)
} : {}))))))

resource azDataShareAccountDataSetDeployment 'Microsoft.DataShare/accounts/shares/dataSets@2021-08-01' = {
  name: replace(replace('${dataShareAccountName}/${dataShareName}/${dataShareDatasetName}', '@environment', environment), '@region', region)
  kind: dataShareDatasetType
  properties: properties
}


output dataShareDataset object = azDataShareAccountDataSetDeployment
