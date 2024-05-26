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

@description('The name of the APIM Gateway the certificate will be deployed to.')
param apimGatewayName string

@allowed([
  'ApplicationInsights'
  'AzureEventHub'
  'AzureMonitor'
])
@description('')
param apimGatewayLoggerType string

@description('')
param apimGatewayLoggerResourceName string

@description('')
param apimGatewayLoggerResourceGroup string

// 1. Get existing Azure APIM resource
resource azApimGatewayExistingResource 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: replace(replace(apimGatewayName, '@environment', environment), '@region', region)
}

// 2. Get existing app insights 
resource azApimGatewayAppInsightsResource 'Microsoft.Insights/components@2020-02-02' existing = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: replace(replace(apimGatewayLoggerResourceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(apimGatewayLoggerResourceGroup, '@environment', environment), '@region', region))
}

// 3. If applicable, set a named value for the function app
resource azApimGatewayAppInsightsNamedValueDeployment 'Microsoft.ApiManagement/service/namedValues@2021-01-01-preview' = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: '${replace(replace(azApimGatewayAppInsightsResource.name, '@environment', environment), '@region', region)}-logger-credentials'
  parent: azApimGatewayExistingResource
  properties: {
    secret: true
    displayName: '${azApimGatewayAppInsightsResource.name}-logger-credentials'
    value: azApimGatewayAppInsightsResource.properties.InstrumentationKey
    tags: [
      'instrumentation-key'
      'app-insights'
      'auto'
    ]
  }
}

// 4. Add App insights logger to APIM
resource azApimGatewayAppInsightsLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: replace(replace('${apimGatewayName}/${apimGatewayLoggerResourceName}', '@environment', environment), '@region', region)
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{${azApimGatewayAppInsightsResource.name}-logger-credentials}}'
    }
    resourceId: azApimGatewayAppInsightsResource.id
  }
}


// TODO: Need to add other functionality besides App Insights for Logging
//resource azApimGatewayAzureEventHubLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (apimGatewayLoggerType == 'AzureEventHub') {
//  name: replace(replace('${apimGatewayName}/${apimGatewayLoggerResourceName}', '@environment', environment), '@region', region)
//  properties: {
//    loggerType: 'azureEventHub'
//     
//  }
//}
//
//resource azApimGatewayAzureMonitorLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (apimGatewayLoggerType == 'AzureMonitor') {
//  name: replace(replace('${apimGatewayName}/${apimGatewayLoggerResourceName}', '@environment', environment), '@region', region)
//  properties: {
//    loggerType: 'azureMonitor'
//
//  }
//}


output apimGatewayLogger object = azApimGatewayAppInsightsLogger
