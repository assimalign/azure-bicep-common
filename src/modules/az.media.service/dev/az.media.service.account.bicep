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

@description('The tags to attach to the resource when deployed')
param mediaServiceTags object = {}

resource mediaServices 'Microsoft.Media/mediaservices@2020-05-01' = {
  name: replace(replace(mediaServiceName, '@environment', environment), '@region', region)
  location: mediaServiceLocation
  identity: {
    type: mediaServiceMsiEnabled ? 'SystemAssigned' : 'None'
  }
  properties: {
     storageAuthentication: 'System'
      encryption: {
        type:  'CustomerKey'
      }
    storageAccounts: [
      {
        id: resourceId()'Microsoft.Storage/storageAccounts', 'mediaServiceStorageAccount')
        type:  ''
      }
    ]
  }
  tags: mediaServiceTags
}
