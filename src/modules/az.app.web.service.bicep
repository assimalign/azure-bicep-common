@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The Resource Prefix that will be appended to the beginning of the resource name')
param prefix string

@description('The name of the web app')
param webAppName string

@allowed([
  'dotnet'
  'java'
  'node'
  'python'
  'php'
])
param webAppPlatform string = 'dotnet'

@allowed([
  'v3.1'  // .NET
  'v3.6'  // Python
  'v5.0'  // .NET
  'v6.0'  // .NET
  'v11.0' // Java
])
@description('')
param webAppPlatformVersion string = 'v3.1'

@description('')
param webAppEnableMsi bool = false

@description('The Application insights that will be used for logging')
param webAppInsights object = {}

@description('The App Service Plan for the application resource')
param webAppServicePlanId string

@description('')
param webAppSettings object = {}



resource azWebAppServiceDeployment 'Microsoft.Web/sites@2021-01-01' = {
  name: replace('${prefix}-${webAppName}', '@environment', environment)
  kind: 'app'
  location: resourceGroup().location
  identity: {
   type: webAppEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: webAppServicePlanId
    siteConfig: {
      appSettings:[
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: webAppInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: webAppInsights.properties.ConnectionString
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Java'
          value: '1'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_NodeJS'
          value: '1'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_PreemptSdk'
          value: 'disabled'
        }
      ]
      netFrameworkVersion: any(webAppPlatform == 'dotnet' ? webAppPlatformVersion: json('null'))
      nodeVersion: any(webAppPlatform == 'node.js' ? webAppPlatformVersion : json('null'))
      pythonVersion: any(webAppPlatform == 'python' ? webAppPlatformVersion : json('null'))
      phpVersion: any(webAppPlatform == 'php' ? webAppPlatformVersion : json('null'))
    }   
  }

  // resource azWebAppExtensionsDeployment 'siteextensions@2021-01-01' = {
  //  name: 'Microsoft.ApplicationInsights.AzureWebSites'
  // }

  resource azWebAppMetadataDeployment  'config@2021-01-01' = {
   name:  'metadata'
   properties: any(webAppPlatform == 'dotnet' ? {
     CURRENT_STACK: 'dotnetcore'
   } : any(webAppPlatform == 'java' ? { 
     CURRENT_STACK: 'java'
   } : any(webAppPlatform == 'php' ? {
     CURRENT_STACK: 'php'
   } : {} )))
  }

  // https://docs.microsoft.com/en-us/azure/templates/microsoft.web/sites/config-authsettingsv2?tabs=bicep
  resource azAppServiceAuthSettingsDeployment 'config@2021-01-01' = if (!empty(webAppSettings.auth)) {
    name: 'authsettingsV2'
    properties: {
      platform: {
        properties:{
          enabled: webAppSettings.auth.enabled
        }
      }
      globalValidation: {
        properties: {
          unauthenticatedClientAction: 'Return401'
          requireAuthentication: true
        }
      }
    }
  }
}


output resource object = azWebAppServiceDeployment
