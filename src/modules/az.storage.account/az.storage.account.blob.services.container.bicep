@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The name of the blob storage service to deploy')
param storageAccountBlobServiceName string 

@description('The name of the blob storage container to deploy')
param storageAccountBlobServiceContainerName string 

@allowed([
  'None'
  'Blob'
  'Container'
])
@description('')
param storageAccountBlobServiceContainerPublicAccess string = 'None'

@description('Enables versioning by making blobs immutable')
param storageAccountBlobServiceContainerVersioningEnabled bool = false


resource azStorageAccountBlobDeployment 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: replace('${storageAccountName}/${storageAccountBlobServiceName}/${storageAccountBlobServiceContainerName}', '@environment', environment)
  properties: {
    publicAccess: storageAccountBlobServiceContainerPublicAccess
    // immutableStorageWithVersioning: {
    //   enabled: storageAccountBlobServiceContainerVersioningEnabled
    // }
  }
}
