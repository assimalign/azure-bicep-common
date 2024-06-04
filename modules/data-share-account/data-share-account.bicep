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

@description('The name of the Azure Data Share Service to be deployed.')
param dataShareAccountName string

@description('The location the Azure Data Share Service will be deployed to.')
param dataShareAccountLocation string = resourceGroup().location

@description('')
param dataShareAccountShares array = []

@description('The tags to attach to the resource when deployed')
param dataShareAccountTags object = {}

resource azDataShareAccountDeployment 'Microsoft.DataShare/accounts@2021-08-01' = {
  name: replace(replace(replace(dataShareAccountName, '@affix', affix), '@environment', environment), '@region', region)
  location: dataShareAccountLocation
  identity: {
    type: 'SystemAssigned'
  }
  tags: union(dataShareAccountTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

module azDataShareAccountShareDeployment 'data-share-account-share.bicep' = [
  for (share, index) in dataShareAccountShares: if (!empty(dataShareAccountShares)) {
    name: 'dsh-act-share-${guid('${azDataShareAccountDeployment.id}-${index}')}'
    params: {
      affix: affix
      region: region
      environment: environment
      dataShareName: share.dataShareName
      dataShareType: share.dataShareType
      dataShareTerms: share.?dataShareTerms
      dataShareDescription: share.?dataShareDescription
      dataShareDatasets: share.?dataShareDatasets
      dataShareAccountName: dataShareAccountName
    }
  }
]

output dataShareAccount object = azDataShareAccountDeployment
