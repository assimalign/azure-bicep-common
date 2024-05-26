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

@description('The netowkr settings for the app service.')
param appServiceNetworkSettings object = {}

@description('The private endpoint settings for the app service.')
param appServicePrivateEndpoint object = {}

@description('The authentication settings for the app serivce.')
param appServiceAuthSettings object = {}

@description('')
param appServiceSiteConfigs object = {}

@description('Custom Attributes to attach to the app service deployment')
param appServiceTags object = {}

func formatName(name string, environment string, region string) string =>
  replace(replace(name, '@environment', environment), '@region', region)

// Format Site Settings 
var siteSettings = [
  for item in items(contains(appServiceSiteConfigs, 'siteSettings') ? appServiceSiteConfigs.siteSettings : {}): {
    name: formatName(item.key, environment, region)
    value: formatName(
      sys.contains(item.value, environment) ? item.value[environment] : item.value.default,
      environment,
      region
    )
  }
]

var authSettingsAudienceValues = contains(appServiceSiteConfigs, 'authSettings')
  ? contains(appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences, environment)
      ? appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences[environment]
      : appServiceSiteConfigs.authSettings.appAuthIdentityProviderAudiences.default
  : []
var authSettingAudiences = [for audience in authSettingsAudienceValues: formatName(audience, environment, region)]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: formatName(appServicePlanName, environment, region)
  scope: resourceGroup(formatName(appServicePlanResourceGroup, environment, region))
}

// 2. Get existing app storage account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: formatName(appServiceStorageAccountName, environment, region)
  scope: resourceGroup(formatName(appServiceStorageAccountResourceGroup, environment, region))
}

// 3. Get existing app insights 
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: formatName(appServiceAppInsightsName, environment, region)
  scope: resourceGroup(formatName(appServiceAppInsightsResourceGroup, environment, region))
}

// 4.1 Deploy Function App, if applicable
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: formatName(appServiceName, environment, region)
  location: appServiceLocation
  kind: appServiceType
  identity: {
    type: appServiceMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    vnetRouteAllEnabled: appServiceNetworkSettings.?routeAllOutboundTraffic ?? false
    virtualNetworkSubnetId: !empty(appServiceNetworkSettings)
      ? formatName(
          resourceId(
            appServiceNetworkSettings.virtualNetworkResourceGroup,
            'Microsoft.Network/VirtualNetworks/subnets',
            appServiceNetworkSettings.virtualNetworkName,
            appServiceNetworkSettings.virtualNetworkSubnetName
          ),
          environment,
          region
        )
      : null
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false
    httpsOnly: contains(appServiceSiteConfigs, 'webSettings') && contains(
        appServiceSiteConfigs.webSettings,
        'httpsOnly'
      )
      ? appServiceSiteConfigs.webSettings.httpsOnly
      : false
    // If there are slots to be deployed then let's have the slots override the site settings
    publicNetworkAccess: appServiceNetworkSettings.?publicNetworkAccess ?? 'Enabled'
    siteConfig: any(empty(appServiceSlots)
      ? {
          appSettings: union(
            [
              {
                name: 'AzureWebJobsStorage'
                value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys('${storageAccount.id}', '${storageAccount.apiVersion}').keys[0].value};EndpointSuffix=core.windows.net'
              }
              {
                name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
                value: appInsights.properties.InstrumentationKey
              }
              {
                name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
                value: appInsights.properties.ConnectionString
              }
              {
                name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
                value: '~2'
                slotSetting: true
              }
              {
                name: 'DiagnosticServices_EXTENSION_VERSION'
                value: '~3'
                slotSetting: true
              }
            ],
            siteSettings
          )
        }
      : {})
  }
  tags: union(appServiceTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
  resource appServiceWebConfigs 'config' = if (contains(appServiceSiteConfigs, 'webSettings')) {
    name: 'web'
    properties: {
      cors: contains(appServiceSiteConfigs.webSettings, 'cors')
        ? contains(appServiceSiteConfigs.webSettings.cors, environment)
            ? appServiceSiteConfigs.webSettings.cors[environment]
            : appServiceSiteConfigs.webSettings.cors.default
        : {}
      ftpsState: contains(appServiceSiteConfigs.webSettings, 'ftpsState')
        ? appServiceSiteConfigs.webSettings.ftpsState
        : 'FtpsOnly'
      alwaysOn: contains(appServiceSiteConfigs.webSettings, 'alwaysOn')
        ? appServiceSiteConfigs.webSettings.alwaysOn
        : false
      phpVersion: contains(appServiceSiteConfigs.webSettings, 'phpVersion')
        ? appServiceSiteConfigs.webSettings.phpVersion
        : null
      nodeVersion: contains(appServiceSiteConfigs.webSettings, 'nodeVersion')
        ? appServiceSiteConfigs.webSettings.nodeVersion
        : null
      javaVersion: contains(appServiceSiteConfigs.webSettings, 'javaVersion')
        ? appServiceSiteConfigs.webSettings.javaVersion
        : null
      pythonVersion: contains(appServiceSiteConfigs.webSettings, 'pythonVersion')
        ? appServiceSiteConfigs.webSettings.pythonVersion
        : null
      netFrameworkVersion: contains(appServiceSiteConfigs.webSettings, 'dotnetVersion')
        ? appServiceSiteConfigs.webSettings.dotnetVersion
        : null
      apiManagementConfig: any(contains(appServiceSiteConfigs.webSettings, 'apimGateway')
        ? {
            id: replace(
              replace(
                resourceId(
                  appServiceSiteConfigs.webSettings.apimGateway.apimGatewayResourceGroup,
                  'Microsoft.ApiManagement/service/apis',
                  appServiceSiteConfigs.webSettings.apimGateway.apimGatewayName,
                  appServiceSiteConfigs.webSettings.apimGateway.apimGatewayApiName
                ),
                '@environment',
                environment
              ),
              '@region',
              region
            )
          }
        : {})
    }
  }
  resource appServiceMetadataConfigs 'config' = if (contains(appServiceSiteConfigs, 'metaSettings')) {
    name: 'metadata'
    properties: appServiceSiteConfigs.metaSettings
  }
  resource appServiceAuthConfigs 'config' = if (!empty(appServiceAuthSettings)) {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: appServiceAuthSettings.appAuthUnauthenticatedAction
      }
      identityProviders: {
        // Azure Active Directory Provider
        azureActiveDirectory: any(appServiceAuthSettings.appAuthIdentityProvider == 'AzureAD'
          ? {
              enabled: true
              registration: contains(appServiceAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                    openIdIssuer: appServiceAuthSettings.appAuthIdentityProviderOpenIdIssuer[environment]
                  }
                : {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                    openIdIssuer: appServiceAuthSettings.appAuthIdentityProviderOpenIdIssuer.default
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
            }
          : null)

        // Facebook Provider
        facebook: any(appServiceAuthSettings.appAuthIdentityProvider == 'Facebook'
          ? {
              enabled: true
              registration: contains(appServiceAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    appId: appServiceAuthSettings.appAuthIdentityProviderClientId[environment]
                    appSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    appId: appServiceAuthSettings.appAuthIdentityProviderClientId.default
                    appSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              graphApiVersion: appServiceAuthSettings.appAuthIdentityProviderGraphApiVersion
              login: {
                scopes: appServiceAuthSettings.appAuthIdentityProviderScopes
              }
            }
          : null)

        // Github Provider
        gitHub: any(appServiceAuthSettings.appAuthIdentityProvider == 'Github'
          ? {
              enabled: true
              registration: contains(appServiceAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              login: {
                scopes: appServiceAuthSettings.appAuthIdentityProviderScopes
              }
            }
          : null)

        // Google Provider
        google: any(appServiceAuthSettings.appAuthIdentityProvider == 'Google'
          ? {
              enabled: true
              registration: contains(appServiceAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    clientId: appServiceAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              login: {
                scopes: appServiceAuthSettings.appAuthIdentityProviderScopes
              }
              validation: {
                allowedAudiences: authSettingAudiences
              }
            }
          : null)
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
module appServiceSlotConfigNames 'app-service-slot-config-names.bicep' = if (!empty(appServiceSlotsConfigNames)) {
  name: 'app-slot-setting-${guid('${appServiceName}/slotConfigNames')}'
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
    appService
  ]
}

// 8. Deploy app slots
module appServiceSlot 'app-service-slot.bicep' = [
  for slot in appServiceSlots: if (!empty(appServiceSlots)) {
    name: !empty(appServiceSlots)
      ? 'app-slot-${guid('${appServiceName}/${slot.appServiceSlotName}')}'
      : 'no-app-service-slots-to-deploy'
    scope: resourceGroup()
    params: {
      region: region
      environment: environment
      appServiceName: appServiceName
      appServiceSlotLocation: appServiceLocation
      appServiceSlotName: slot.appServiceSlotName
      appServiceSlotType: appServiceType
      appServiceSlotFunctions: slot.appServiceSlotFunctions
      appServiceSlotMsiEnabled: appServiceMsiEnabled
      appServiceSlotMsiRoleAssignments: appServiceMsiRoleAssignments
      appServiceSlotInsightsName: appServiceAppInsightsName
      appServiceSlotInsightsResourceGroup: appServiceAppInsightsResourceGroup
      appServiceSlotPlanName: appServicePlanName
      appServiceSlotPlanResourceGroup: appServicePlanResourceGroup
      appServiceSlotAuthSettings: appServiceAuthSettings
      appServiceSlotNetworkSettings: slot.?appServiceSlotNetworkSettings
      appServiceSlotPrivateEndpoint: slot.?appServiceSlotPrivateEndpoint
      appServiceSlotSiteConfigs: appServiceSiteConfigs
      appServiceSlotStorageAccountName: appServiceStorageAccountName
      appServiceSlotStorageAccountResourceGroup: appServiceStorageAccountResourceGroup
      appServiceSlotTags: appServiceTags
    }
    dependsOn: [
      appServiceSlotConfigNames
    ]
  }
]

// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module rbac '../rbac/rbac.bicep' = [
  for appRoleAssignment in appServiceMsiRoleAssignments: if (appServiceMsiEnabled == true && !empty(appServiceMsiRoleAssignments)) {
    name: 'app-rbac-${guid('${appServiceName}-${appRoleAssignment.resourceRoleName}')}'
    scope: resourceGroup(formatName(appRoleAssignment.resourceGroupToScopeRoleAssignment,environment, region))
    params: {
      region: region
      environment: environment
      resourceRoleName: appRoleAssignment.resourceRoleName
      resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
      resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
      resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
      resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
      resourcePrincipalIdReceivingRole: appService.identity.principalId
    }
  }
]

module privateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(appServicePrivateEndpoint)) {
  name: !empty(appServicePrivateEndpoint)
    ? toLower('apps-private-ep-${guid('${appService.id}/${appServicePrivateEndpoint.privateEndpointName}')}')
    : 'no-app-sv-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: appServicePrivateEndpoint.privateEndpointName
    privateEndpointLocation: appServicePrivateEndpoint.?privateEndpointLocation ?? appServiceLocation
    privateEndpointDnsZoneName: appServicePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-azurewebsites-net'
    privateEndpointDnsZoneResourceGroup: appServicePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: appServicePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: appServicePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: appServicePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: appService.id
    privateEndpointTags: appServicePrivateEndpoint.?privateEndpointTags
    privateEndpointGroupIds: [
      'sites'
    ]
  }
}

// 10. Return Deployment Output
output appService object = appService
