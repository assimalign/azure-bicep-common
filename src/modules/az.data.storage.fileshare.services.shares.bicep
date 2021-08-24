@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The name of the blob storage service to deploy')
param storageAccountFileShareServiceName string 

@description('The name of the blob storage container to deploy')
param storageAccountFileShareName string 

@description('')
param storageAccountFileAccessTier string



resource azStorageAccountFileShareDeployment 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' =  {
  name: replace('${storageAccountName}/${storageAccountFileShareServiceName}/${storageAccountFileShareName}', '@environment', environment)
  properties: {
    accessTier: storageAccountFileAccessTier
  }
}
