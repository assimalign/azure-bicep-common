@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The Function App Name to be deployed')
param appServiceName string

@allowed([
  'web'
  'functionapp'
  'functionapp,linux'
])
@description('appType')
param appServiceSlotType string

@description('appType')
param appServiceSlotFunctions array = []

@description('A boolean flag for turning on System Managed Identity')
param appServiceSlotMsiEnabled bool = false

@description('')
param appServiceSlotMsiRoleAssignments array = []

@description('The name of the Function App Slot')
param appServiceSlotName string

@allowed([
  'dotnet'
  'java'
  'node'
  'python'
  'php'
])
@description('The platform for the Function app: .NET Core, Java, Node.js, etc.,')
param appServiceSlotPlatform string

@description('An Object specifying the storage specs for the deployment')
param appServiceSlotStorageAccountName string

@description('The resource group where the storage account resource group')
param appServiceSlotStorageAccountResourceGroup string

@description('The Application insights that will be used for logging')
param appServiceSlotInsightsName string

@description('The resource group where the app insights lives in.')
param appServiceSlotInsightsResourceGroup string

@description('The App Service Plan for the application resource')
param appServiceSlotPlanName string

@description('The resource group name in which the app service plan lives')
param appServiceSlotPlanResourceGroup string = resourceGroup().name

@description('The settings for the app service deployment')
param appServiceSlotSettings object

@description('Custom Attributes to attach to the app service deployment')
param appServiceSlotTags object = {}




var appSiteSettings = [for setting in appServiceSlotSettings.site: {
  name: replace(replace(setting.name, '@environment', environment), '@region', region)
  value: replace(replace(setting.value, '@environment', environment), '@region', region)
}]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: replace(replace(appServiceSlotPlanName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotPlanResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(replace(appServiceSlotStorageAccountName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotStorageAccountResourceGroup, '@environment', environment), '@region', region))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: replace(replace(appServiceSlotInsightsName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotInsightsResourceGroup, '@environment', environment), '@region', region))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceFunctionSlotDeployment 'Microsoft.Web/sites/slots@2021-01-01' = if (appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux') {
  name: appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux' ? replace(replace('${appServiceName}/${appServiceSlotName}', '@environment', environment), '@region', region) : 'no-function-app-slot-to-deploy'
  location: resourceGroup().location
  kind: appServiceSlotType
  identity: {
    type: appServiceSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: appServiceSlotSettings.httpsOnly
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
          value: appServiceSlotPlatform
        }
      ], appSiteSettings)
    }
  }
  tags: appServiceSlotTags 
}

// 4.2 Deploy Web App, if applicable
resource azAppServiceWebSlotDeployment 'Microsoft.Web/sites/slots@2021-01-01' = if (appServiceSlotType == 'web') {
  name: appServiceSlotType == 'web' ? replace('${appServiceName}/${appServiceSlotName}', '@environment', environment) : 'no-web-app/no-web-app-slot-to-deploy'
  location: resourceGroup().location
  identity: {
    type: appServiceSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
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
          value: appServiceSlotPlatform
        }
      ], appSiteSettings) // If there are slots to be deployed then let's have the slots override the site settings
    }
  }
  tags: appServiceSlotTags
}

// 5. Configure Custom Function Settings (Will use this to disable functions in slots such as: Service Bus Listeners, Timers, etc.,)
module azAppServiceFunctionSlotFunctionsDeployment 'az.app.service.slot.function.bicep' = [for function in appServiceSlotFunctions: if (!empty(appServiceSlotFunctions) && (appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux')) {
  name: !empty(appServiceSlotFunctions) && (appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux') ? toLower('az-app-slot-func-${guid('${appServiceName}/${appServiceSlotName}/${function.name}')}') : 'no-func-app/no-function-app-slot-functions-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appName: appServiceName
    appSlotName: appServiceSlotName
    appSlotFunctionName: function.name
    appSlotFunctionIsDiabled: function.isEnabled
  }
  dependsOn: [
    azAppServiceFunctionSlotDeployment
  ]
}]

// 6. Set the Slots Identity Provider if applicable
module azAppServiceAuthSettings 'az.app.service.slot.config.auth.v2.settings.bicep' = if (!empty(appServiceSlotSettings.authentication ?? {})) {
  name: !empty(appServiceSlotSettings.authentication ?? {}) ? 'az-app-slot-config-auth-${guid('${appServiceName}/${appServiceSlotName}')}' : 'no-app-service-slot-auth-settings-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appName: appServiceName
    appSlotName: appServiceSlotName
    appSlotAuthUnauthenticatedAction: appServiceSlotSettings.authentication.action
    appSlotAuthIdentityProviderType: appServiceSlotSettings.authentication.identityProvider
    appSlotAuthIdentityProviderAudiences: appServiceSlotSettings.authentication.identityAudiences
    appSlotAuthIdentityProviderClientSecretName: appServiceSlotSettings.authentication.identityClientSecretName
    appSlotAuthIdentityProviderClientId: appServiceSlotSettings.authentication.identityClientId
    appSlotAuthIdentityProviderOpenIdIssuer: appServiceSlotSettings.authentication.identityOpenIdIssuer
    appSlotAuthIdentityProviderGraphApiVersion: appServiceSlotSettings.authentication.identityGraphApiVersion
    appSlotAuthIdentityProviderScopes: appServiceSlotSettings.authentication.identityScopes
  }
  dependsOn: [
    azAppServiceFunctionSlotDeployment
  ]
}

// 7. Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azAppServiceFunctionRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for appSlotRoleAssignment in appServiceSlotMsiRoleAssignments: if (appServiceSlotMsiEnabled == true && !empty(appServiceSlotMsiRoleAssignments)) {
  name: 'az-app-service-slot-rbac-${guid('${appServiceName}-${appServiceSlotName}-${appSlotRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appSlotRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: appSlotRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appSlotRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appSlotRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appSlotRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appSlotRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux' ? azAppServiceFunctionSlotDeployment.identity.principalId : azAppServiceWebSlotDeployment.identity.principalId
  }
  dependsOn: [
    azAppServiceAuthSettings
    azAppServiceFunctionSlotFunctionsDeployment
  ]
}]

// 8. Return Deployment Output
output resource object = appServiceSlotType == 'web' ? azAppServiceWebSlotDeployment : azAppServiceFunctionSlotDeployment
