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

@description('The name of the blob storage service to deploy')
param storageAccountQueueServiceName string

@description('The name of the blob storage container to deploy')
param storageAccountQueueServiceQueueName string

resource storageAccountQueueServieQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = {
  name: replace(replace(replace('${storageAccountName}/${storageAccountQueueServiceName}/${storageAccountQueueServiceQueueName}', '@affix', affix), '@environment', environment), '@region', region)
}

output storageAccountQueue object = storageAccountQueueServieQueue
