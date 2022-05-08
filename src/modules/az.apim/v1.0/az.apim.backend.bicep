@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('The name of the API Management resource')
param apimName string

@description('')
param apimBackendName string

@description('')
param apimBackendTitle string = ''

@description('')
param apimBackendDescription string = ''

@description('')
param apimBackendRuntimeUrl string = ''

@allowed([
  'CustomUrl'
  'FunctionApp'
  'WebApp'
])
@description('')
param apimBackendType string = 'CustomUrl'

@description('If adding an Azure Resource then specify the name of the resource to be added')
param apimBackendSiteResourceName string = ''

@description('If adding an Azure Resource then specify the name of the resource group the resource lives in')
param apimBackendSiteResourceGroupName string = ''


// 1. Get existing Azure APIM resource
resource azApimExistingResource 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: replace(replace(apimName, '@environment', environment), '@region', region)
}

// 2. If applicable, get existing app service to apply backend information
resource azAppServiceExistingResource 'Microsoft.Web/sites@2021-01-15' existing = if (apimBackendType == 'FunctionApp' || apimBackendType == 'web') {
  name:  replace(replace(apimBackendSiteResourceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(apimBackendSiteResourceGroupName, '@environment', environment), '@region', region))
}

// 3. If applicable, set a named value for the function app
resource azApimFunctionAppNamedValueDeployment 'Microsoft.ApiManagement/service/namedValues@2021-01-01-preview' = if (apimBackendType == 'FunctionApp') {
  name: '${replace(replace(apimBackendName, '@environment', environment), '@region', region)}-bicep-key'
  parent: azApimExistingResource
  properties: {
    secret: true
    displayName: '${azAppServiceExistingResource.name}-bicep-key'
    value: listKeys('${azAppServiceExistingResource.id}/host/default', '2019-08-01').functionKeys.default
    tags: [
      'key'
      'function'
      'auto'
    ]
  }
}

// 4.1 If applicable, set the funciton app backend resource too allow routing access to Http Triggers 
resource azApimFunctionAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimBackendType == 'FunctionApp') {
  name: apimBackendType == 'FunctionApp' ? replace(replace(apimBackendName, '@environment', environment), '@region', region) : 'no-backend-function-app-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: empty(apimBackendTitle) ? azAppServiceExistingResource.name : apimBackendTitle
    description: empty(apimBackendDescription) ? 'Function App import for: ${azAppServiceExistingResource.name}' : apimBackendDescription
    protocol: 'http'
    url: replace(replace(apimBackendRuntimeUrl, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${azAppServiceExistingResource.id}', '///', '/')
    credentials: {
       header: {
         'x-functions-key': [
           '{{${azApimFunctionAppNamedValueDeployment.properties.displayName}}}'
         ]
       }
    }
  }
}

// 4.2 If applicable, set the web app backend resource too allow routing access to Http Triggers 
resource azApimWebAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimBackendType == 'WebApp') {
  name: apimBackendType == 'WebApp' ? replace(replace(apimBackendName, '@environment', environment), '@region', region) : 'no-backend-web-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: empty(apimBackendTitle) ? azAppServiceExistingResource.name : apimBackendTitle
    description: empty(apimBackendDescription) ? 'Web App backend import for: ${azAppServiceExistingResource.name}' : apimBackendDescription
    protocol: 'http'
    url: replace(replace(apimBackendRuntimeUrl, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${azAppServiceExistingResource.id}', '///', '/')
  }
}

// 4.3 If applicable, set the web app backend resource too allow routing access to Http Triggers 
resource azApimCustomUrlBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimBackendType == 'CustomUrl') {
  name: apimBackendType == 'CustomUrl' ? replace(replace(apimBackendName, '@environment', environment), '@region', region) : 'no-backend-custom-url-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: apimBackendTitle
    description: apimBackendDescription
    protocol: 'http'
    url: replace(replace(apimBackendRuntimeUrl, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${azAppServiceExistingResource.id}', '///', '/')
  }
}
