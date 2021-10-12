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
param appSlotType string

@description('appType')
param appSlotFunctions array = []

@description('A boolean flag for turning on System Managed Identity')
param appSlotMsiEnabled bool = false

@description('')
param appSlotMsiRoleAssignments array = []

@description('The name of the Function App Slot')
param appSlotName string

@allowed([
  'dotnet'
  'java'
  'node'
  'python'
  'php'
])
@description('The platform for the Function app: .NET Core, Java, Node.js, etc.,')
param appSlotPlatform string

@description('An Object specifying the storage specs for the deployment')
param appSlotStorageAccountName string

@description('The resource group where the storage account resource group')
param appSlotStorageAccountResourceGroup string

@description('The Application insights that will be used for logging')
param appSlotInsightsName string

@description('The resource group where the app insights lives in.')
param appSlotInsightsResourceGroup string

@description('The App Service Plan for the application resource')
param appSlotPlanName string

@description('The resource group name in which the app service plan lives')
param appSlotPlanResourceGroup string = resourceGroup().name

@description('The settings for the app service deployment')
param appSlotSettings object

@description('Custom Attributes to attach to the app service deployment')
param appSlotTags object = {}



// Format App Site Settings 
var appSiteSettings = [for setting in appSlotSettings.site: {
  name: replace(replace(setting.name, '@environment', environment), '@location', location)
  value: replace(replace(setting.value, '@environment', environment), '@location', location)
}]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: replace(replace(appSlotPlanName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appSlotPlanResourceGroup, '@environment', environment), '@location', location))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(replace(appSlotStorageAccountName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appSlotStorageAccountResourceGroup, '@environment', environment), '@location', location))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: replace(replace(appSlotInsightsName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appSlotInsightsResourceGroup, '@environment', environment), '@location', location))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceFunctionSlotDeployment 'Microsoft.Web/sites/slots@2021-01-01' = if (appSlotType == 'functionapp' || appSlotType == 'functionapp,linux') {
  name: appSlotType == 'functionapp' || appSlotType == 'functionapp,linux' ? replace(replace('${appName}/${appSlotName}', '@environment', environment), '@location', location) : 'no-function-app-slot-to-deploy'
  location: resourceGroup().location
  kind: appSlotType
  identity: {
    type: appSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: appSlotSettings.httpsOnly
    clientAffinityEnabled: false
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
          value: appSlotPlatform
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ], appSiteSettings)
    }
  }
  tags: appSlotTags
}

// 4.2 Deploy Web App, if applicable
resource azAppServiceWebSlotDeployment 'Microsoft.Web/sites/slots@2021-01-01' = if (appSlotType == 'web') {
  name: appSlotType == 'web' ? replace('${appName}/${appSlotName}', '@environment', environment) : 'no-web-app/no-web-app-slot-to-deploy'
  location: resourceGroup().location
  identity: {
    type: appSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
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
          value: appSlotPlatform
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ], appSiteSettings) // If there are slots to be deployed then let's have the slots override the site settings
    }
  }
  tags: appSlotTags
}



// 5. Configure Custom Function Settings (Will use this to disable functions in slots such as: Service Bus Listeners, Timers, etc.,)
module azAppServiceFunctionSlotFunctionsDeployment 'az.app.service.slot.function.bicep' = [for function in appSlotFunctions: if (!empty(appSlotFunctions) && (appSlotType == 'functionapp' || appSlotType == 'functionapp,linux')) {
  name: !empty(appSlotFunctions) && (appSlotType == 'functionapp' || appSlotType == 'functionapp,linux') ? toLower('az-app-slot-func-${guid('${appName}/${appSlotName}/${function.name}')}') : 'no-func-app/no-function-app-slot-functions-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    appName: appName
    appSlotName: appSlotName
    appSlotFunctionName: function.name
    appSlotFunctionIsDiabled: function.isEnabled
  }
  dependsOn: [
    azAppServiceFunctionSlotDeployment
  ]
}]

// 6. Set the Slots Identity Provider if applicable
module azAppServiceAuthSettings 'az.app.service.slot.config.auth.v2.settings.bicep' = if (!empty(appSlotSettings.authentication ?? {})) {
  name: !empty(appSlotSettings.authentication ?? {}) ? 'az-app-slot-config-auth-${guid('${appName}/${appSlotName}')}' : 'no-app-service-slot-auth-settings-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    appName: appName
    appSlotName: appSlotName
    appSlotAuthUnauthenticatedAction: appSlotSettings.authentication.action
    appSlotAuthIdentityProviderType: appSlotSettings.authentication.identityProvider
    appSlotAuthIdentityProviderAudiences: appSlotSettings.authentication.identityAudiences
    appSlotAuthIdentityProviderClientSecretName: appSlotSettings.authentication.identityClientSecretName
    appSlotAuthIdentityProviderClientId: appSlotSettings.authentication.identityClientId
    appSlotAuthIdentityProviderOpenIdIssuer: appSlotSettings.authentication.identityOpenIdIssuer
    appSlotAuthIdentityProviderGraphApiVersion: appSlotSettings.authentication.identityGraphApiVersion
    appSlotAuthIdentityProviderScopes: appSlotSettings.authentication.identityScopes
  }
  dependsOn: [
    azAppServiceFunctionSlotDeployment
  ]
}

// 7. Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azAppServiceFunctionRoleAssignment 'az.sec.role.assignment.bicep' = [for appSlotRoleAssignment in appSlotMsiRoleAssignments: if (appSlotMsiEnabled == true && !empty(appSlotMsiRoleAssignments)) {
  name: 'az-app-service-slot-rbac-${guid('${appName}-${appSlotName}-${appSlotRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appSlotRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@location', location))
  params: {
    location: location
    environment: environment
    resourceRoleName: appSlotRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appSlotRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appSlotRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appSlotRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appSlotRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: appSlotType == 'functionapp' || appSlotType == 'functionapp,linux' ? azAppServiceFunctionSlotDeployment.identity.principalId : azAppServiceWebSlotDeployment.identity.principalId
  }
  dependsOn: [
    azAppServiceAuthSettings
    azAppServiceWebSlotDeployment
    azAppServiceFunctionSlotDeployment
    azAppServiceFunctionSlotFunctionsDeployment
  ]
}]

// 8. Return Deployment Output
output resource object = appSlotType == 'web' ? azAppServiceWebSlotDeployment : azAppServiceFunctionSlotDeployment
