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
param apimBackendName string

@allowed([
  'CustomUrl'
  'FunctionApp'
  'WebApp'
])
@description('')
param apimBackendType string = 'FunctionApp'

@description('')
param apimBackendSiteName string

@description('')
param apimBackendSiteResourceName string



resource azFunctionAppResource 'Microsoft.Web/sites/functions@2021-01-15' existing = {
  name: replace('${apimBackendSiteName}/${apimBackendSiteResourceName}', '@environment', environment)
}



resource azApimBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = {
  name: replace('${apimName}/${apimBackendName}', '@environment', environment)
  properties: {
    protocol: 'http'
    url: azFunctionAppResource.properties.invoke_url_template
    resourceId: azFunctionAppResource.id
  }
}
