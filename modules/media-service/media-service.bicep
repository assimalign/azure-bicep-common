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

@description('The name of the Media Service to be deployed.')
param mediaServiceName string

@description('The location the Media Service will be deployed to.')
param mediaServiceLocation string = resourceGroup().location

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param mediaServiceMsiEnabled bool = false

@description('')
param mediaServiceStorageAccountName string

@description('')
param mediaServiceStorageAccountResourceGroup string = resourceGroup().location

@description('The tags to attach to the resource when deployed')
param mediaServiceTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource mediaServices 'Microsoft.Media/mediaservices@2021-06-01' = {
  name: formatName(mediaServiceName, affix, environment, region)
  location: mediaServiceLocation
  identity: {
    type: mediaServiceMsiEnabled ? 'SystemAssigned' : 'None'
  }
  properties: {
    storageAccounts: [
      {
        id: resourceId(
          formatName(mediaServiceStorageAccountResourceGroup, affix, environment, region),
          'Microsoft.Storage/storageAccounts',
          formatName(mediaServiceStorageAccountName, affix, environment, region)
        )
        type: 'Primary'
      }
    ]
  }
  tags: union(mediaServiceTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
 })
}
