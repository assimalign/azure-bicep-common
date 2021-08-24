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
param storageAccountTableServiceName string = 'default'

@description('The name of the blob storage container to deploy')
param storageAccountTableName string 


resource azStorageAccountTableDeployment 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' =  {
  name: replace('${storageAccountName}/${storageAccountTableServiceName}/${storageAccountTableName}', '@environment', environment)
}
