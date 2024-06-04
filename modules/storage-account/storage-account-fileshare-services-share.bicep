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

@description('The name of the storage account to deploy. Must only contain alphanumeric characters')
param storageAccountName string

@description('The name of the file share service name.')
param storageAccountFileShareServiceName string = 'default'

@description('The name of the blob storage container to deploy')
param storageAccountFileShareServiceShareName string

@allowed([
  'Cool'
  'Hot'
  'Premium'
  'TransactionOptimized'
])
@description('Access tier for specific share. GpV2 account can choose between TransactionOptimized (default), Hot, and Cool. FileStorage account can choose Premium.')
param storageAccountFileShareServiceShareAccessTier string

resource storageAccountFileShareServiceFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  name: replace(replace(replace('${storageAccountName}/${storageAccountFileShareServiceName}/${storageAccountFileShareServiceShareName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    accessTier: storageAccountFileShareServiceShareAccessTier
  }
}

output storageAccountFileShareServiceFileShare object = storageAccountFileShareServiceFileShare
