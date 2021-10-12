@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('A prefix or suffix identifying the deployment location as part of the naming convention of the resource')
param location string = ''

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

@description('Turns on System Managed Identity for the creted resources')
param appMsiEnabled bool = false

@description('')
param appMsiRoleAssignments array = []

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

@description('Custom Attributes to attach to the app service deployment')
param appServiceTags object = {}

// **************************************************************************************** //
//                              Function App Deployment                                     //
// **************************************************************************************** //

// Format Site Settings 
var appSiteSettings = [for setting in appSettings.site: {
  name: replace(replace(setting.name, '@environment', environment), '@location', location)
  value: replace(replace(setting.value, '@environment', environment), '@location', location)
}]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: replace(replace(appPlanName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appPlanResourceGroup, '@environment', environment), '@location', location))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(replace(appStorageAccountName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appStorageAccountResourceGroup, '@environment', environment), '@location', location))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: replace(replace(appInsightsName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appInsightsResourceGroup, '@environment', environment), '@location', location))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceFunctionDeployment 'Microsoft.Web/sites@2021-01-01' = if (appType == 'functionapp' || appType == 'functionapp,linux') {
  name: appType == 'functionapp' || appType == 'functionapp,linux' ? replace(replace('${appName}', '@environment', environment), '@location', location) : 'no-function-app-to-deploy'
  location: resourceGroup().location
  kind: appType
  identity: {
    type: appMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: appSettings.httpsOnly
    clientAffinityEnabled: false
    // If there are slots to be deployed then let's have the slots override the site settings
    siteConfig: any(empty(appSlots) ? { 
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
    } : { })
  }
  tags: appServiceTags
}

// 4.2 Deploy Web App, if applicable
resource azAppServiceWebDeployment 'Microsoft.Web/sites@2021-01-01' = if (appType == 'web') {
  name: appType == 'web' ? replace(replace('${appName}', '@environment', environment), '@location', location) : 'no-web-app-to-deploy'
  location: resourceGroup().location
  kind: appType
  identity: {
    type: appMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    // If there are slots to be deployed then let's have the slots override the site settings
    siteConfig: any(empty(appSlots) ? {
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
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ], appSiteSettings) // If there are slots to be deployed then let's have the slots override the site settings
    } : {})
  }
  tags: appServiceTags
}

// 5. Set the Identity Provider if applicable
module azAppServiceAuthSettings 'az.app.service.config.auth.v2.settings.bicep' = if (!empty(appSettings.authentication ?? {})) {
  name: !empty(appSettings.authentication ?? {}) ? 'az-app-service-config-auth-${guid(appName)}' : 'no-app-service-auth-settings-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
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
module azAppServiceWebMetadataDeployment 'az.app.service.config.app.metadata.bicep' = if (appType == 'web') {
  name: 'az-app-service-config-meta-${guid(appName)}'
  scope: resourceGroup()
  params: {
    location: location
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

// 7. Deploy app slots
module azAppServiceSlotDeployment 'az.app.service.slot.bicep' = [for slot in appSlots: if (!empty(appSlots)) {
  name: !empty(appSlots) ? 'az-app-service-slot-${guid('${appName}/${slot.name}')}' : 'no-app-service-slots-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    appName: appName
    appSlotName: slot.name
    appSlotType: appType
    appSlotFunctions: slot.functions
    appSlotMsiEnabled: appMsiEnabled
    appSlotMsiRoleAssignments: appMsiRoleAssignments
    appSlotInsightsName: appInsightsName
    appSlotInsightsResourceGroup: appInsightsResourceGroup
    appSlotPlanName: appPlanName
    appSlotPlanResourceGroup: appPlanResourceGroup
    appSlotPlatform: appPlatform
    appSlotSettings: appSettings
    appSlotStorageAccountName: appStorageAccountName
    appSlotStorageAccountResourceGroup: appStorageAccountResourceGroup
  }
  dependsOn: [
    azAppServiceFunctionDeployment
    azAppServiceWebDeployment
  ]
}]


// 8. Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azAppServiceRoleAssignment 'az.sec.role.assignment.bicep' = [for appRoleAssignment in appMsiRoleAssignments: if (appMsiEnabled == true && !empty(appMsiRoleAssignments)) {
  name: 'az-app-service-rbac-${guid('${appName}-${appRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@location', location))
  params: {
    location: location
    environment: environment
    resourceRoleName: appRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: appType == 'functionapp' || appType == 'functionapp,linux' ? azAppServiceFunctionDeployment.identity.principalId : azAppServiceWebDeployment.identity.principalId
  }
  dependsOn: [
    azAppServiceAuthSettings
    azAppServiceSlotDeployment
    azAppServiceWebDeployment
    azAppServiceFunctionDeployment
  ]
}]

// 9. Return Deployment Output
output resource object = appType == 'web' ? azAppServiceWebDeployment : azAppServiceFunctionDeployment
