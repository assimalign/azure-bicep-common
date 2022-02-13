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

@description('The location/region the Azure App Service will be deployed to. ')
param appServiceLocation string = resourceGroup().location

@allowed([
  'web'
  'functionapp'
  'functionapp,linux'
])
@description('appType')
param appServiceType string

@allowed([
  'dotnet'
  'java'
  'node'
  'python'
  'php'
])
@description('The platform for the Function app: .NET Core, Java, Node.js, etc.,')
param appServicePlatform string

@description('Turns on System Managed Identity for the creted resources')
param appServiceMsiEnabled bool = false

@description('Azure RBAC Role Assignment for Managed System Identity.')
param appServiceMsiRoleAssignments array = []

@description('Deploys App Slots for the app service')
param appServiceSlots array = []

@description('Adds specific names to to identify slot specific settings')
param appServiceSlotsConfigNames object = {}

@description('An Object specifying the storage specs for the deployment')
param appServiceStorageAccountName string

@description('The resource group where the storage account resource group')
param appServiceStorageAccountResourceGroup string = resourceGroup().name

@description('The Application insights that will be used for logging')
param appServiceAppInsightsName string

@description('The resource group where the app insights lives in.')
param appServiceAppInsightsResourceGroup string = resourceGroup().name

@description('The App Service Plan for the application resource')
param appServicePlanName string

@description('The resource group name in which the app service plan lives')
param appServicePlanResourceGroup string = resourceGroup().name

@description('')
param appServiceSiteConfigs object = {}

@description('Custom Attributes to attach to the app service deployment')
param appServiceTags object = {}

// **************************************************************************************** //
//                              Function App Deployment                                     //
// **************************************************************************************** //

// Format Site Settings 
var siteSettings = [for setting in appServiceSiteConfigs.siteSettings: {
  name: replace(replace(setting.name, '@environment', environment), '@region', region)
  value: replace(replace(setting.value, '@environment', environment), '@region', region)
}]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: replace(replace(appServicePlanName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServicePlanResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: replace(replace(appServiceStorageAccountName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceStorageAccountResourceGroup, '@environment', environment), '@region', region))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: replace(replace(appServiceAppInsightsName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceAppInsightsResourceGroup, '@environment', environment), '@region', region))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceFunctionDeployment 'Microsoft.Web/sites@2021-02-01' = if (appServiceType == 'functionapp' || appServiceType == 'functionapp,linux') {
  name: appServiceType == 'functionapp' || appServiceType == 'functionapp,linux' ? replace(replace('${appServiceName}', '@environment', environment), '@region', region) : 'no-function-app-to-deploy'
  location: appServiceLocation
  kind: appServiceType
  identity: {
    type: appServiceMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: contains(appServiceSiteConfigs, 'siteHttpsOnly') ? appServiceSiteConfigs.siteHttpsOnly : false
    clientAffinityEnabled: false
    // If there are slots to be deployed then let's have the slots override the site settings
    siteConfig: any(empty(appServiceSlots) ? {
      alwaysOn: contains(appServiceSiteConfigs, 'siteAlwaysOn') ? appServiceSiteConfigs.siteAlwaysOn : false
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
          value: appServicePlatform
        }
      ], siteSettings)
    } : {})
  }
  tags: appServiceTags
  resource azAppServiceLinkApim 'config' = if (contains(appServiceSiteConfigs, 'siteApimSettings')) {
    name: 'web'
    properties: {
      apiManagementConfig: {
        id: replace(replace(resourceId(appServiceSiteConfigs.siteApimSettings.apimResourceGroupName, 'MMicrosoft.ApiManagement/apis', appServiceSiteConfigs.siteApimSettings.apimName, appServiceSiteConfigs.siteApimSettings.apimApiName), '@environment', environment), '@region', region)
      }
    }
  }
}

// 4.2 Deploy Web App, if applicable
resource azAppServiceWebDeployment 'Microsoft.Web/sites@2021-01-01' = if (appServiceType == 'web') {
  name: appServiceType == 'web' ? replace('${appServiceName}', '@environment', environment) : 'no-web-app-to-deploy'
  location: appServiceLocation
  kind: appServiceType
  identity: {
    type: appServiceMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: contains(appServiceSiteConfigs, 'siteHttpsOnly') ? appServiceSiteConfigs.siteHttpsOnly : false
    // If there are slots to be deployed then let's have the slots override the site settings
    siteConfig: any(empty(appServiceSlots) ? {
      alwaysOn: contains(appServiceSiteConfigs, 'siteAlwaysOn') ? appServiceSiteConfigs.siteAlwaysOn : false
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
          value: appServicePlatform
        }
      ], siteSettings) // If there are slots to be deployed then let's have the slots override the site settings
    } : {})
  }
  tags: appServiceTags
  resource azAppServiceLinkApim 'config' = if (contains(appServiceSiteConfigs, 'siteApimSettings')) {
    name: 'web'
    properties: {
      apiManagementConfig: {
        id: replace(replace(resourceId(appServiceSiteConfigs.siteApimSettings.apimResourceGroupName, 'MMicrosoft.ApiManagement/apis', appServiceSiteConfigs.siteApimSettings.apimName, appServiceSiteConfigs.siteApimSettings.apimApiName), '@environment', environment), '@region', region)
      }
    }
  }
}

// 5. Set the Identity Provider if applicable
module azAppServiceAuthSettings 'az.app.service.config.auth.v2.settings.bicep' = if (contains(appServiceSiteConfigs, 'siteAuthSettings')) {
  name: contains(appServiceSiteConfigs, 'siteAuthSettings') ? 'az-app-service-config-auth-${guid(appServiceName)}' : 'no-app-service-auth-settings-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appServiceName: appServiceName
    appServiceAuthUnauthenticatedAction: appServiceSiteConfigs.siteAuthSettings.appServiceAuthAction
    appServiceAuthIdentityProviderType: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityProvider
    appServiceAuthIdentityProviderAudiences: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityAudiences
    appServiceAuthIdentityProviderClientSecretName: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityClientSecretName
    appServiceAuthIdentityProviderClientId: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityClientId
    appServiceAuthIdentityProviderOpenIdIssuer: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityOpenIdIssuer
    appServiceAuthIdentityProviderGraphApiVersion: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityGraphApiVersion
    appServiceAuthIdentityProviderScopes: appServiceSiteConfigs.siteAuthSettings.appServiceAuthIdentityScopes
  }
  dependsOn: [
    azAppServiceFunctionDeployment
    azAppServiceWebDeployment
  ]
}

// 6. Set Web App Metadata 
module azAppServiceWebMetadataDeployment 'az.app.service.config.app.metadata.bicep' = if (appServiceType == 'web') {
  name: 'az-app-service-config-meta-${guid(appServiceName)}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appServiceName: appServiceName
    appServiceMetadata: any(appServicePlatform == 'dotnet' ? {
      CURRENT_STACK: 'dotnetcore'
    } : any(appServicePlatform == 'java' ? {
      CURRENT_STACK: 'java'
    } : any(appServicePlatform == 'php' ? {
      CURRENT_STACK: 'php'
    } : any(appServicePlatform == 'node' ? {
      CURRENT_STACK: 'node'
    } : {}))))
  }
  dependsOn: [
    azAppServiceWebDeployment
  ]
}

// 7. Sets App Service Config Names only
module azAppServiceSlotSpecificSettingsDeployment 'az.app.service.slot.config.names.bicep' = if (!empty(appServiceSlotsConfigNames)) {
  name: 'az-app-slot-setting-${guid('${appServiceName}/slotConfigNames')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appName: appServiceName
    appSlotSettingNames: appServiceSlotsConfigNames.appSettingNames
    appSlotConnectionStringNames: appServiceSlotsConfigNames.connectionStringSettingNames
    appSlotAzureStorageConfigNames: appServiceSlotsConfigNames.storageAccountSettingNames
  }
  dependsOn: [
    azAppServiceFunctionDeployment
    azAppServiceWebDeployment
  ]
}

// 8. Deploy app slots
module azAppServiceSlotDeployment 'az.app.service.slot.bicep' = [for slot in appServiceSlots: if (!empty(appServiceSlots)) {
  name: !empty(appServiceSlots) ? 'az-app-service-slot-${guid('${appServiceName}/${slot.name}')}' : 'no-app-service-slots-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    appServiceName: appServiceName
    appServiceSlotLocation: appServiceLocation
    appServiceSlotName: slot.appServiceSlotName
    appServiceSlotType: appServiceType
    appServiceSlotFunctions: slot.functions
    appServiceSlotMsiEnabled: appServiceMsiEnabled
    appServiceSlotMsiRoleAssignments: appServiceMsiRoleAssignments
    appServiceSlotInsightsName: appServiceAppInsightsName
    appServiceSlotInsightsResourceGroup: appServiceAppInsightsResourceGroup
    appServiceSlotPlanName: appServicePlanName
    appServiceSlotPlanResourceGroup: appServicePlanResourceGroup
    appServiceSlotPlatform: appServicePlatform
    appServiceSlotSiteConfigs: appServiceSiteConfigs
    appServiceSlotStorageAccountName: appServiceStorageAccountName
    appServiceSlotStorageAccountResourceGroup: appServiceStorageAccountResourceGroup
    appServiceSlotTags: appServiceTags
  }
  dependsOn: [
    azAppServiceSlotSpecificSettingsDeployment
  ]
}]

// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azAppServiceRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for appRoleAssignment in appServiceMsiRoleAssignments: if (appServiceMsiEnabled == true && !empty(appServiceMsiRoleAssignments)) {
  name: 'az-app-service-rbac-${guid('${appServiceName}-${appRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: appRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: appServiceType == 'functionapp' || appServiceType == 'functionapp,linux' ? azAppServiceFunctionDeployment.identity.principalId : azAppServiceWebDeployment.identity.principalId
  }
  dependsOn: [
    azAppServiceAuthSettings
    azAppServiceSlotDeployment
  ]
}]

// 10. Return Deployment Output
output resource object = appServiceType == 'web' ? azAppServiceWebDeployment : azAppServiceFunctionDeployment
