@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Azure Data Share Service to be deployed.')
param dataShareName string

@description('')
param dataShareTerms string = ''

@description('')
param dataShareDescription string = ''

@description('The name of the Azure Data Share Service to be deployed.')
param dataShareAccountName string

@allowed([
  'InPlace'
  'CopyBased'
])
@description('The type of the Data Share Account')
param dataShareType string

@description('')
param dataShareDatasets array = []

resource azDataShareAccountShareDeployment 'Microsoft.DataShare/accounts/shares@2021-08-01' = {
  name: replace(replace('${dataShareAccountName}/${dataShareName}', '@environment', environment), '@region', region)
  properties: {
    shareKind: dataShareType
    terms: dataShareTerms
    description: dataShareDescription
  }
}

module azDataShareDatasetDeployment 'az.data.share.account.share.dataset.bicep' = [for (dataset, index) in dataShareDatasets: if (!empty(dataShareDatasets)) {
  name: 'az-datashare-${guid('${azDataShareAccountShareDeployment.id}-${index}')}'
  params: {
    region: region
    environment: environment
    dataShareName: dataShareName
    dataShareAccountName: dataShareAccountName
    dataShareDatasetName: dataset.dataShareDatasetName
    dataShareDatasetConfigs: dataset.dataShareDatasetConfigs
    dataShareDatasetType: dataset.dataShareDatasetType
  }
}]

output dataShare object = azDataShareAccountShareDeployment
