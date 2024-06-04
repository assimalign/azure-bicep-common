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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get existing Azure APIM resource
resource apimService 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: formatName(apimGatewayName, affix, environment, region)
}

// 2. Get existing app insights 
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: formatName(apimGatewayLoggerResourceName, affix, environment, region)
  scope: resourceGroup(formatName(apimGatewayLoggerResourceGroup, affix, environment, region))
}

// 3. If applicable, set a named value for the function app
resource apimServiceNamedValues 'Microsoft.ApiManagement/service/namedValues@2021-01-01-preview' = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: '${formatName(appInsights.name, affix, environment, region)}-logger-credentials'
  parent: apimService
  properties: {
    secret: true
    displayName: '${appInsights.name}-logger-credentials'
    value: appInsights.properties.InstrumentationKey
    tags: [
      'instrumentation-key'
      'app-insights'
      'auto'
    ]
  }
}

// 4. Add App insights logger to APIM
resource apimServiceLoggers 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (apimGatewayLoggerType == 'ApplicationInsights') {
  name: formatName('${apimGatewayName}/${apimGatewayLoggerResourceName}', affix, environment, region)
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{${appInsights.name}-logger-credentials}}'
    }
    resourceId: appInsights.id
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


output apimGatewayLogger object = apimServiceLoggers
