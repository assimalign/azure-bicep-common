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

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The name of the blob storage container to deploy')
param storageAccountFileShareName string

@description('')
param storageAccountFileAccessTier string

@description('The name of the file share service name.')
param storageAccountFileShareServiceName string = 'default'

resource azStorageAccountFileShareDeployment 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-08-01' = {
  name: replace(replace('${storageAccountName}/${storageAccountFileShareServiceName}/${storageAccountFileShareName}', '@environment', environment), '@region', region)
  properties: {
    accessTier: storageAccountFileAccessTier
  }
}
