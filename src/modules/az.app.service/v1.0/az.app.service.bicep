@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The Function App Name to be deployed')
param appServiceName string

@description('The location/region the Azure App Service will be deployed to. ')
param appServiceLocation string = resourceGroup().location

@allowed([
  'app'
  'app,linux'
  'app,linux,container'
  'app,container,windows'
  'functionapp'
  'functionapp,linux'
])
@description('appType')
param appServiceType string

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



// Format Site Settings 
var siteSettings = [for item in items(contains(appServiceSiteConfigs, 'siteSettings') ? appServiceSiteConfigs.siteSettings : {}): {
  name: replace(replace(item.key, '@environment', environment), '@region', region)
  value: replace(replace(sys.contains(item.value, environment) ? item.value[environment] : item.value.default, '@environment', environment), '@region', region)
}]


var authSettingsAudienceValues = contains(appServiceSiteConfigs, 'authSettings') ? contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences, environment) ? appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences[environment] : appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences.default : []
var authSettingAudiences = [for audience in authSettingsAudienceValues: replace(replace(audience, '@environment', environment), '@region', region)]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: replace(replace(appServicePlanName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServicePlanResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: replace(replace(appServiceStorageAccountName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceStorageAccountResourceGroup, '@environment', environment), '@region', region))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: replace(replace(appServiceAppInsightsName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceAppInsightsResourceGroup, '@environment', environment), '@region', region))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceDeployment 'Microsoft.Web/sites@2022-09-01' = {
  name: replace(replace(appServiceName, '@environment', environment), '@region', region)
  location: appServiceLocation
  kind: appServiceType
  identity: {
    type: appServiceMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    vnetRouteAllEnabled: contains(appServiceSiteConfigs, 'virtualNetworkSettings') && contains(appServiceSiteConfigs.virtualNetworkSettings, 'routeAllOutboundTraffic') ? appServiceSiteConfigs.virtualNetworkSettings.routeAllOutboundTraffic : false
    virtualNetworkSubnetId:contains(appServiceSiteConfigs, 'virtualNetworkSettings') ? replace(replace(resourceId(appServiceSiteConfigs.virtualNetworkSettings.virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', appServiceSiteConfigs.virtualNetworkSettings.virtualNetworkName, appServiceSiteConfigs.virtualNetworkSettings.virtualNetworkSubnetName), '@environment', environment), '@region', region) : null
    serverFarmId: azAppServicePlanResource.id
    clientAffinityEnabled: false
    httpsOnly: contains(appServiceSiteConfigs, 'webSettings') && contains(appServiceSiteConfigs.webSettings, 'httpsOnly') ? appServiceSiteConfigs.webSettings.httpsOnly : false
    // If there are slots to be deployed then let's have the slots override the site settings
    siteConfig: any(empty(appServiceSlots) ? {
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
            name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
            value: '~2'
            slotSetting: true
          }
        ],
        siteSettings)
    } : {})
  }
  tags: union(appServiceTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
  resource azAppServiceWebConfigs 'config' = if (contains(appServiceSiteConfigs, 'webSettings')) {
    name: 'web'
    properties: {
      cors: contains(appServiceSiteConfigs.webSettings, 'cors') ? appServiceSiteConfigs.webSettings.cors : {}
      ftpsState: contains(appServiceSiteConfigs.webSettings, 'ftpsState') ? appServiceSiteConfigs.webSettings.ftpsState : 'FtpsOnly'
      alwaysOn: contains(appServiceSiteConfigs.webSettings, 'alwaysOn') ? appServiceSiteConfigs.webSettings.alwaysOn : false
      phpVersion: contains(appServiceSiteConfigs.webSettings, 'phpVersion') ? appServiceSiteConfigs.webSettings.phpVersion : null
      nodeVersion: contains(appServiceSiteConfigs.webSettings, 'nodeVersion') ? appServiceSiteConfigs.webSettings.nodeVersion : null
      javaVersion: contains(appServiceSiteConfigs.webSettings, 'javaVersion') ? appServiceSiteConfigs.webSettings.javaVersion : null
      pythonVersion: contains(appServiceSiteConfigs.webSettings, 'pythonVersion') ? appServiceSiteConfigs.webSettings.pythonVersion : null
      netFrameworkVersion: contains(appServiceSiteConfigs.webSettings, 'dotnetVersion') ? appServiceSiteConfigs.webSettings.dotnetVersion : null
      apiManagementConfig: any(contains(appServiceSiteConfigs.webSettings, 'apimGateway') ? {
        id: replace(replace(resourceId(appServiceSiteConfigs.webSettings.apimGateway.apimGatewayResourceGroup, 'Microsoft.ApiManagement/service/apis', appServiceSiteConfigs.webSettings.apimGateway.apimGatewayName, appServiceSiteConfigs.webSettings.apimGateway.apimGatewayApiName), '@environment', environment), '@region', region)
      } : {})
    }
  }
  resource azAppServiceMetadataConfigs 'config' = if (contains(appServiceSiteConfigs, 'metaSettings')) {
    name: 'metadata'
    properties: appServiceSiteConfigs.metaSettings
  }
  resource azAppServiceAuthSettings 'config' = if (contains(appServiceSiteConfigs, 'authSettings')) {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: appServiceSiteConfigs.authSettings.appAuthUnauthenticatedAction
      }
      identityProviders: {
        // Azure Active Directory Provider
        azureActiveDirectory: any(appServiceSiteConfigs.authSettings.appAuthIdentityProvider == 'AzureAD' ? {
          enabled: true
          registration: contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
            openIdIssuer: appServiceSiteConfigs.authSettings.appAuthIdentityProviderOpenIdIssuer[environment]
          } : {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
            openIdIssuer: appServiceSiteConfigs.authSettings.appAuthIdentityProviderOpenIdIssuer.default
          }
          validation: {
            allowedAudiences: authSettingAudiences
          }
          isAutoProvisioned: false
          login: {
            tokenStore: {
              enabled: true
            }
          }
        } : null)

        // Facebook Provider
        facebook: any(appServiceSiteConfigs.authSettings.appAuthIdentityProvider == 'Facebook' ? {
          enabled: true
          registration: contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            appId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            appSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            appId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            appSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          graphApiVersion: appServiceSiteConfigs.authSettings.appAuthIdentityProviderGraphApiVersion
          login: {
            scopes: appServiceSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
        } : null)

        // Github Provider
        gitHub: any(appServiceSiteConfigs.authSettings.appAuthIdentityProvider == 'Github' ? {
          enabled: true
          registration: contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          login: {
            scopes: appServiceSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
        } : null)

        // Google Provider
        google: any(appServiceSiteConfigs.authSettings.appAuthIdentityProvider == 'Google' ? {
          enabled: true
          registration: contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            clientId: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          login: {
            scopes: appServiceSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
          validation: {
            allowedAudiences: authSettingAudiences
          }
        } : null)
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
    }
  }
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
    azAppServiceDeployment
  ]
}

// 8. Deploy app slots
module azAppServiceSlotDeployment 'az.app.service.slot.bicep' = [for slot in appServiceSlots: if (!empty(appServiceSlots)) {
  name: !empty(appServiceSlots) ? 'az-app-service-slot-${guid('${appServiceName}/${slot.appServiceSlotName}')}' : 'no-app-service-slots-to-deploy'
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
    resourcePrincipalIdReceivingRole: azAppServiceDeployment.identity.principalId
  }
}]

// 10. Return Deployment Output
output appService object = azAppServiceDeployment
