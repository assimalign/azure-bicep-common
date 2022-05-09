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

@description('The name of the Media Service to be deployed.')
param mediaServiceName string

@description('The location the Media Service will be deployed to.')
param mediaServiceLocation string = resourceGroup().location

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param mediaServiceMsiEnabled bool = false

@description('')
param mediaServiceStorageAccount object

@description('The tags to attach to the resource when deployed')
param mediaServiceTags object = {}

resource mediaServices 'Microsoft.Media/mediaservices@2021-06-01' = {
  name: replace(replace(mediaServiceName, '@environment', environment), '@region', region)
  location: mediaServiceLocation
  identity: {
    type: mediaServiceMsiEnabled ? 'SystemAssigned' : 'None'
  }
  properties: {
    storageAccounts: [
      {
        id: resourceId(contains(mediaServiceStorageAccount, 'mediaServiceStorageAccountResourceGroup') ? mediaServiceStorageAccount.mediaServiceStorageAccountResourceGroup : resourceGroup().name, 'Microsoft.Storage/storageAccounts', mediaServiceStorageAccount.mediaServiceStorageAccountName)
        type: 'Primary'
      }
    ]
  }
  tags: mediaServiceTags
}
