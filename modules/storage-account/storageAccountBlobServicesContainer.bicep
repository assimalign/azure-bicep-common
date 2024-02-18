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

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The name of the blob storage service to deploy')
param storageAccountBlobServiceName string

@description('The name of the blob storage container to deploy')
param storageAccountBlobContainerName string

@allowed([
  'None'
  'Blob'
  'Container'
])
@description('')
param storageAccountBlobContainerPublicAccess string = 'None'

resource storageAccountBlobServiceContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: replace(replace('${storageAccountName}/${storageAccountBlobServiceName}/${storageAccountBlobContainerName}', '@environment', environment), '@region', region)
  properties: {
    publicAccess: storageAccountBlobContainerPublicAccess
  }
}

output storageAccountBlobServiceContainer object = storageAccountBlobServiceContainer
