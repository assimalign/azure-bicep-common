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

@description('The name of the blob storage service to deploy')
param storageAccountTableServiceName string = 'default'

@description('The name of the blob storage container to deploy')
param storageAccountTableServiceTableName string 


resource azStorageAccountTableDeployment 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-08-01' =  {
  name: replace(replace('${storageAccountName}/${storageAccountTableServiceName}/${storageAccountTableServiceTableName}', '@environment', environment), '@region', region)
}
