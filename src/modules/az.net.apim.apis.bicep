@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the API Management resource')
param apimName string

@description('')
param apimApiName string

@description('')
param apimApiDescription string = ''

@description('')
param apimApiPath string

@description('')
param apimApiEndpoint string




resource apiManagementInstance 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: replace('${apimName}/${apimApiName}', '@environment', environment)
  properties: {
    path: apimApiPath
    serviceUrl: apimApiEndpoint
    apiType: 'http'
    description: apimApiDescription
    displayName: replace(apimApiName, '@environment', environment)
  }
}
