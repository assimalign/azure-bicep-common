@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The Function App Name to be deployed')
param appName string

@allowed([
  'web'
  'functionapp'
  'functionapp,linux' 
])
@description('appType')
param appType string

@allowed([
  'dotnet'
  'java'
  'node'
  'python'
  'php'
])
@description('The platform for the Function app: .NET Core, Java, Node.js, etc.,')
param appPlatform string

@description('The Runtime Version of the specified language')
param appPlatformVersion string = ''

@description('Turns on System Managed Identity for the creted resources')
param appEnableMsi bool = false

@description('Deploys App Slots for the app service')
param appSlots array = []

@description('An Object specifying the storage specs for the deployment')
param appStorageAccountName string

@description('The resource group where the storage account resource group')
param appStorageAccountResourceGroup string 

@description('The Application insights that will be used for logging')
param appInsightsName string

@description('The resource group where the app insights lives in.')
param appInsightsResourceGroup string

@description('The App Service Plan for the application resource')
param appPlanName string

@description('The resource group name in which the app service plan lives')
param appPlanResourceGroup string = resourceGroup().name

@description('The settings for the app service deployment')
param appSettings object



// **************************************************************************************** //
//                              Function App Deployment                                     //
// **************************************************************************************** //

var appSiteSettings = [for setting in appSettings.site: {
  name: replace(setting.name, '@environment', environment)
  value: replace(setting.value, '@environment', environment)
}]


// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: replace(appPlanName, '@environment', environment)
  scope: resourceGroup(replace(appPlanResourceGroup, '@environment', environment))
}


// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(appStorageAccountName, '@environment', environment)
  scope: resourceGroup(replace(appStorageAccountResourceGroup, '@environment', environment))
}


// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: replace(appInsightsName, '@environment', environment)
  scope: resourceGroup(replace(appInsightsResourceGroup, '@environment', environment))
}


// 4. Deploy Function App
resource azAppServiceFunctionDeployment 'Microsoft.Web/sites@2021-01-01' = if (appType == 'functionapp' || appType == 'functionapp,linux') {
  name: appType == 'functionapp' || appType == 'functionapp,linux' ? replace('${appName}', '@environment', environment) : 'no-function-app-to-deploy'
  location: resourceGroup().location
  kind: appType
  identity: {
   type: appEnableMsi == true ? 'SystemAssigned' : 'None'
  } 
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: appSettings.httpsOnly
    clientAffinityEnabled: false
    // https://docs.microsoft.com/en-us/azure/app-service/reference-app-settings?tabs=kudu%2Cdotnet
    siteConfig: {
      appSettings: union([
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${azAppServiceStorageResource.name};AccountKey=${listKeys('${azAppServiceStorageResource.id}', '${azAppServiceStorageResource.apiVersion}').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: azAppServiceInsightsResource.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: azAppServiceInsightsResource.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: appPlatform
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ], appSiteSettings)
      // netFrameworkVersion: any(appPlatform == 'dotnet' ? appPlatformVersion: json('null'))
      // nodeVersion: any(appPlatform == 'node.js' ? appPlatformVersion : json('null'))
      // pythonVersion: any(appPlatform == 'python' ? appPlatformVersion : json('null'))
      // phpVersion: any(appPlatform == 'php' ? appPlatformVersion : json('null'))
    } 
  }
}


// 5. Deploy the Web App Service
resource azAppServiceWebDeployment 'Microsoft.Web/sites@2021-01-01' = if (appType == 'web') {
  name: appType == 'web' ? replace('${appName}', '@environment', environment) : 'no-web-app-to-deploy'
  location: resourceGroup().location
  kind: appType
  identity: {
   type: appEnableMsi == true ? 'SystemAssigned' : 'None'
  } 
  properties: {
    serverFarmId: azAppServicePlanResource.id    
    siteConfig: {
      appSettings: union([
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${azAppServiceStorageResource.name};AccountKey=${listKeys('${azAppServiceStorageResource.id}', '${azAppServiceStorageResource.apiVersion}').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${azAppServiceStorageResource.name};AccountKey=${listKeys('${azAppServiceStorageResource.id}', '${azAppServiceStorageResource.apiVersion}').keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: azAppServiceInsightsResource.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: azAppServiceInsightsResource.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: appPlatform
        }
        // {
        //   name: 'WEBSITE_CONTENTSHARE'
        //   value: 
        // }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ], appSiteSettings)
    } 
  }
}


// Set the Identity Provider if applicable
module azAppServiceAuthSettings 'az.app.service.config.auth.v2.settings.bicep' = if (!empty(appSettings.authentication ?? {})) {
  name: !empty(appSettings.authentication ?? {}) ? 'az-app-service-config-auth-${guid(appName)}' : 'no-app-service-auth-settings-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    appName: appName
    appAuthUnauthenticatedAction: appSettings.authentication.action
    appAuthIdentityProviderType: appSettings.authentication.identityProvider
    appAuthIdentityProviderAudiences: appSettings.authentication.identityAudiences
    appAuthIdentityProviderClientSecretName: appSettings.authentication.identityClientSecretName
    appAuthIdentityProviderClientId: appSettings.authentication.identityClientId
    appAuthIdentityProviderOpenIdIssuer: appSettings.authentication.identityOpenIdIssuer
    appAuthIdentityProviderGraphApiVersion: appSettings.authentication.identityGraphApiVersion
   appAuthIdentityProviderScopes: appSettings.authentication.identityScopes
  }
  dependsOn: [
    azAppServiceFunctionDeployment
    azAppServiceWebDeployment
  ]
}

// 6. Set Web App Metadata 
module azAppServiceWebMetadataDeployment  'az.app.service.config.app.metadata.bicep' = if (appType == 'web') {
  name: 'az-app-service-config-meta-${guid(appName)}'
  scope: resourceGroup()
  params: {
    environment: environment
    appName: appName
    appMetadata: any(appPlatform == 'dotnet' ? {
      CURRENT_STACK: 'dotnetcore'
    } : any(appPlatform == 'java' ? { 
      CURRENT_STACK: 'java'
    } : any(appPlatform == 'php' ? {
      CURRENT_STACK: 'php'
    } : any(appPlatform == 'node' ? {
      CURRENT_STACK: 'node'
    } : {}))))
  }
  dependsOn: [
    azAppServiceWebDeployment
  ]
 }


// Deploy app slots
module azAppServiceSlotDeployment 'az.app.service.slot.bicep' = [for slot in appSlots: if(!empty(slot)) {
  name: !empty(appSlots) ? 'az-app-service-slot-${guid('${appName}/${slot.name}')}' : 'no-slots-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    appName: appName
    appSlotName: slot.name
    appSlotType: appType
    appSlotEnableMsi: appEnableMsi
  }
  dependsOn: [
    azAppServiceFunctionDeployment
    azAppServiceWebDeployment
  ]
}]



 // module azAppServiceWebSettingsDeployment 'az.app.service.app.settings.bicep' = if(appType == 'web') {
//   name: 'az-app-service-web-config-${guid(appName)}'
//   scope: resourceGroup()
//   params: {
//     environment: environment
//     appName: appName
//     appSettings: {
//       XDT_MicrosoftApplicationInsights_Mode: 'recommended'
//       APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
//       APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
//       ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
//       DiagnosticServices_EXTENSION_VERSION: '~3'
//       InstrumentationEngine_EXTENSION_VERSION: 'disabled'
//       SnapshotDebugger_EXTENSION_VERSION: 'disabled'
//       XDT_MicrosoftApplicationInsights_BaseExtensions: 'disabled'
//     }
//   }
//   dependsOn: [
//     azAppServiceDeployment
//   ]
// }

// module azAppServiceNodeSettingsDeployment 'az.app.service.app.settings.bicep' = if(appPlatform == 'node') {
//   name: 'az-app-service-node-config-${guid(appName)}'
//   scope: resourceGroup()
//   params: {
//     environment: environment
//     appName: appName
//     appSettings: {
//       FUNCTIONS_WORKER_RUNTIME: appPlatform
//       WEBSITE_NODE_DEFAULT_VERSION: '~${appPlatformVersion}'
//     }
//   }
//   dependsOn: [
//     azAppServiceDeployment
//   ]
// }

// module azAppServiceNodeWebSettingsDeployment 'az.app.service.app.settings.bicep' = if(appPlatform == 'node' && appType == 'web') {
//   name: 'az-app-service-node-web-config-${guid(appName)}'
//   scope: resourceGroup()
//   params: {
//     environment: environment
//     appName: appName
//     appSettings: {
//       XDT_MicrosoftApplicationInsights_NodeJS: '1'
//       WEBSITE_NODE_DEFAULT_VERSION: '~${appPlatformVersion}'
//     }
//   }
//   dependsOn: [
//     azAppServiceDeployment
//   ]
// }


output resource object = appType == 'web' ? azAppServiceWebDeployment : azAppServiceFunctionDeployment
