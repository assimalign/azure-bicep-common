@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('The name of the API Management resource')
param apimGatewayName string

@description('')
param apimGatewayBackendName string

@description('')
param apimGatewayBackendTitle string = ''

@description('')
param apimGatewayBackendDescription string = ''

@description('')
param apimGatewayBackendRuntimeUrl object = {}

@allowed([
  'CustomUrl'
  'FunctionApp'
  'WebApp'
])
@description('')
param apimGatewayBackendType string = 'CustomUrl'

@description('If adding an Azure Resource then specify the name of the resource to be added')
param apimGatewayBackendSiteResourceName string = ''

@description('If adding an Azure Resource then specify the name of the resource group the resource lives in')
param apimGatewayBackendSiteResourceGroupName string = ''

// 1. Get existing Azure APIM resource
resource azApimExistingResource 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: replace(replace(apimGatewayName, '@environment', environment), '@region', region)
}

// 2. If applicable, get existing app service to apply backend information
resource azAppServiceExistingResource 'Microsoft.Web/sites@2021-01-15' existing = if (apimGatewayBackendType == 'FunctionApp' || apimGatewayBackendType == 'web') {
  name: replace(replace(apimGatewayBackendSiteResourceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(apimGatewayBackendSiteResourceGroupName, '@environment', environment), '@region', region))
}

// 3. If applicable, set a named value for the function app
resource azApimFunctionAppNamedValueDeployment 'Microsoft.ApiManagement/service/namedValues@2021-01-01-preview' = if (apimGatewayBackendType == 'FunctionApp') {
  name: '${replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region)}-bicep-key'
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
resource azApimFunctionAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimGatewayBackendType == 'FunctionApp') {
  name: apimGatewayBackendType == 'FunctionApp' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-function-app-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: empty(apimGatewayBackendTitle) ? azAppServiceExistingResource.name : apimGatewayBackendTitle
    description: empty(apimGatewayBackendDescription) ? 'Function App import for: ${azAppServiceExistingResource.name}' : apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
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
resource azApimWebAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimGatewayBackendType == 'WebApp') {
  name: apimGatewayBackendType == 'WebApp' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-web-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: empty(apimGatewayBackendTitle) ? azAppServiceExistingResource.name : apimGatewayBackendTitle
    description: empty(apimGatewayBackendDescription) ? 'Web App backend import for: ${azAppServiceExistingResource.name}' : apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${azAppServiceExistingResource.id}', '///', '/')
  }
}

// 4.3 If applicable, set the web app backend resource too allow routing access to Http Triggers 
resource azApimCustomUrlBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimGatewayBackendType == 'CustomUrl') {
  name: apimGatewayBackendType == 'CustomUrl' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-custom-url-to-deploy'
  parent: azApimExistingResource
  properties: {
    title: apimGatewayBackendTitle
    description: apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${azAppServiceExistingResource.id}', '///', '/')
  }
}
