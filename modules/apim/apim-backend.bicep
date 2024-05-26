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
resource apimGateway 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: replace(replace(apimGatewayName, '@environment', environment), '@region', region)
}

// 2. If applicable, get existing app service to apply backend information
resource appService 'Microsoft.Web/sites@2023-01-01' existing = if (apimGatewayBackendType == 'FunctionApp' || apimGatewayBackendType == 'web') {
  name: replace(replace(apimGatewayBackendSiteResourceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(apimGatewayBackendSiteResourceGroupName, '@environment', environment), '@region', region))
}

// 3. If applicable, set a named value for the function app
resource azApimFunctionAppNamedValueDeployment 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = if (apimGatewayBackendType == 'FunctionApp') {
  name: '${replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region)}-bicep-key'
  parent: apimGateway
  properties: {
    secret: true
    displayName: '${appService.name}-bicep-key'
    value: listKeys('${appService.id}/host/default', '2019-08-01').functionKeys.default
    tags: [
      'key'
      'function'
      'auto'
    ]
  }
}

// 4.1 If applicable, set the funciton app backend resource too allow routing access to Http Triggers 
resource azApimFunctionAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2022-08-01' = if (apimGatewayBackendType == 'FunctionApp') {
  name: apimGatewayBackendType == 'FunctionApp' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-function-app-to-deploy'
  parent: apimGateway
  properties: {
    title: empty(apimGatewayBackendTitle) ? appService.name : apimGatewayBackendTitle
    description: empty(apimGatewayBackendDescription) ? 'Function App import for: ${appService.name}' : apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${appService.id}', '///', '/')
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
resource azApimWebAppBackendDeployment 'Microsoft.ApiManagement/service/backends@2022-08-01' = if (apimGatewayBackendType == 'WebApp') {
  name: apimGatewayBackendType == 'WebApp' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-web-to-deploy'
  parent: apimGateway
  properties: {
    title: empty(apimGatewayBackendTitle) ? appService.name : apimGatewayBackendTitle
    description: empty(apimGatewayBackendDescription) ? 'Web App backend import for: ${appService.name}' : apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${appService.id}', '///', '/')
  }
}

// 4.3 If applicable, set the web app backend resource too allow routing access to Http Triggers 
resource azApimCustomUrlBackendDeployment 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = if (apimGatewayBackendType == 'CustomUrl') {
  name: apimGatewayBackendType == 'CustomUrl' ? replace(replace(apimGatewayBackendName, '@environment', environment), '@region', region) : 'no-backend-custom-url-to-deploy'
  parent: apimGateway
  properties: {
    title: apimGatewayBackendTitle
    description: apimGatewayBackendDescription
    protocol: 'http'
    url: replace(replace(contains(apimGatewayBackendRuntimeUrl, environment) ? apimGatewayBackendRuntimeUrl[environment] : apimGatewayBackendRuntimeUrl.default, '@environment', environment), '@region', region)
    resourceId: replace('${az.environment().resourceManager}/${appService.id}', '///', '/')
  }
}
