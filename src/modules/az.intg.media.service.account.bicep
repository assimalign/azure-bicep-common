@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'



resource mediaServices 'Microsoft.Media/mediaServices@2020-05-01' = {
  name: 'name'
  location: resourceGroup().location
  properties: {
    storageAccounts: [
      {
        id: resourceId('Microsoft.Storage/storageAccounts', 'mediaServiceStorageAccount')
        type: 'Primary'
      }
    ]
  }
}
