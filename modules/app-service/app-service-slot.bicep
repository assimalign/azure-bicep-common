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

@description('The Function App Name to be deployed')
param appServiceName string

@allowed([
  'app'
  'app,linux'
  'app,linux,container'
  'app,container,windows'
  'functionapp'
  'functionapp,linux'
])
@description('appServiceSlotType')
param appServiceSlotType string

@description('appType')
param appServiceSlotFunctions array = []

@description('A boolean flag for turning on System Managed Identity')
param appServiceSlotMsiEnabled bool = false

@description('')
param appServiceSlotMsiRoleAssignments array = []

@description('The name of the Function App Slot')
param appServiceSlotName string

@description('The location/region the Azure App Service will be deployed to. ')
param appServiceSlotLocation string = resourceGroup().location

@description('An Object specifying the storage specs for the deployment')
param appServiceSlotStorageAccountName string

@description('The resource group where the storage account resource group')
param appServiceSlotStorageAccountResourceGroup string = resourceGroup().name

@description('The Application insights that will be used for logging')
param appServiceSlotInsightsName string

@description('The resource group where the app insights lives in.')
param appServiceSlotInsightsResourceGroup string = resourceGroup().name

@description('The App Service Plan for the application resource')
param appServiceSlotPlanName string

@description('The resource group name in which the app service plan lives')
param appServiceSlotPlanResourceGroup string = resourceGroup().name

@description('The netowkr settings for the app service.')
param appServiceSlotNetworkSettings object = {}

@description('The private endpoint settings for the app service.')
param appServiceSlotPrivateEndpoint object = {}

@description('The authentication settings for the app serivce.')
param appServiceSlotAuthSettings object = {}

@description('The settings for the app service deployment')
param appServiceSlotSiteConfigs object

@description('Custom Attributes to attach to the app service deployment')
param appServiceSlotTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// Format Site Settings 
var siteSettings = [
  for item in items(contains(appServiceSlotSiteConfigs, 'siteSettings') ? appServiceSlotSiteConfigs.siteSettings : {}): {
    name: formatName(item.key, affix, environment, region)
    value: formatName(
      contains(item.value, environment) ? item.value[environment] : item.value.default,
      affix,
      environment,
      region
    )
  }
]

// Formt auth settings if any
var authSettingsAudienceValues = contains(appServiceSlotSiteConfigs, 'authSettings')
  ? contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences, environment)
      ? appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences[environment]
      : appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences.default
  : []
var authSettingAudiences = [
  for audience in authSettingsAudienceValues: formatName(audience, affix, environment, region)
]

// known naming delimiter
var delimiters = [
  '-'
  '_'
]


// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: formatName(appServiceSlotPlanName, affix, environment, region)
  scope: resourceGroup(formatName(appServiceSlotPlanResourceGroup, affix, environment, region))
}

// 2. Get existing app storage account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: join(split(formatName(appServiceSlotStorageAccountName, affix, environment, region), delimiters), '')
  scope: resourceGroup(formatName(appServiceSlotStorageAccountResourceGroup, affix, environment, region))
}

// 3. Get existing app insights 
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: formatName(appServiceSlotInsightsName, affix, environment, region)
  scope: resourceGroup(formatName(appServiceSlotInsightsResourceGroup, affix, environment, region))
}

// 4.1 Deploy Function App, if applicable
resource appServiceSlot 'Microsoft.Web/sites/slots@2023-01-01' = {
  name: formatName('${appServiceName}/${appServiceSlotName}', affix, environment, region)
  location: appServiceSlotLocation
  kind: appServiceSlotType
  identity: {
    type: appServiceSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    vnetRouteAllEnabled: appServiceSlotNetworkSettings.?routeAllOutboundTraffic ?? false
    virtualNetworkSubnetId: !empty(appServiceSlotNetworkSettings)
      ? resourceId(
          formatName(appServiceSlotNetworkSettings.virtualNetworkResourceGroup, affix, environment, region),
          'Microsoft.Network/VirtualNetworks/subnets',
          formatName(appServiceSlotNetworkSettings.virtualNetworkName, affix, environment, region),
          formatName(appServiceSlotNetworkSettings.virtualNetworkSubnetName, affix, environment, region)
        )
      : null
    serverFarmId: appServicePlan.id
    httpsOnly: contains(appServiceSlotSiteConfigs, 'webSettings') && contains(
        appServiceSlotSiteConfigs.webSettings,
        'httpsOnly'
      )
      ? appServiceSlotSiteConfigs.webSettings.httpsOnly
      : false
    // If there are slots to be deployed then let's have the slots override the site settings
    publicNetworkAccess: appServiceSlotNetworkSettings.?allowPublicNetworkAccess ?? 'Enabled'
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: contains(appServiceSlotSiteConfigs, 'alwaysOn') ? appServiceSlotSiteConfigs.alwaysOn : false
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
        ],
        siteSettings
      )
    }
  }
  tags: union(appServiceSlotTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })

  resource appServiceLinkApim 'config' = if (contains(appServiceSlotSiteConfigs, 'webSettings')) {
    name: 'web'
    properties: {
      cors: contains(appServiceSlotSiteConfigs.webSettings, 'cors')
        ? contains(appServiceSlotSiteConfigs.webSettings.cors, environment)
            ? appServiceSlotSiteConfigs.webSettings.cors[environment]
            : appServiceSlotSiteConfigs.webSettings.cors.default
        : {}
      ftpsState: contains(appServiceSlotSiteConfigs.webSettings, 'ftpsState')
        ? appServiceSlotSiteConfigs.webSettings.ftpsState
        : 'FtpsOnly'
      alwaysOn: contains(appServiceSlotSiteConfigs.webSettings, 'alwaysOn')
        ? appServiceSlotSiteConfigs.webSettings.alwaysOn
        : false
      phpVersion: contains(appServiceSlotSiteConfigs.webSettings, 'phpVersion')
        ? appServiceSlotSiteConfigs.webSettings.phpVersion
        : null
      nodeVersion: contains(appServiceSlotSiteConfigs.webSettings, 'nodeVersion')
        ? appServiceSlotSiteConfigs.webSettings.nodeVersion
        : null
      javaVersion: contains(appServiceSlotSiteConfigs.webSettings, 'javaVersion')
        ? appServiceSlotSiteConfigs.webSettings.javaVersion
        : null
      pythonVersion: contains(appServiceSlotSiteConfigs.webSettings, 'pythonVersion')
        ? appServiceSlotSiteConfigs.webSettings.pythonVersion
        : null
      netFrameworkVersion: contains(appServiceSlotSiteConfigs.webSettings, 'dotnetVersion')
        ? appServiceSlotSiteConfigs.webSettings.dotnetVersion
        : null
      apiManagementConfig: any(contains(appServiceSlotSiteConfigs.webSettings, 'apimGateway')
        ? {
            id: resourceId(
              formatName(
                appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayResourceGroup,
                affix,
                environment,
                region
              ),
              'Microsoft.ApiManagement/service/apis',
              formatName(appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayName, affix, environment, region),
              formatName(
                appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayApiName,
                affix,
                environment,
                region
              )
            )
          }
        : {})
    }
  }
  resource appServiceMetadataConfigs 'config' = if (contains(appServiceSlotSiteConfigs, 'metaSettings')) {
    name: 'metadata'
    properties: appServiceSlotSiteConfigs.metaSettings
  }
  resource appServiceSlotAuthConfigs 'config' = if (contains(appServiceSlotSiteConfigs, 'authSettings')) {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: appServiceSlotAuthSettings.appAuthUnauthenticatedAction
      }
      identityProviders: {
        // Azure Active Directory Provider
        azureActiveDirectory: any(appServiceSlotAuthSettings.appAuthIdentityProvider == 'AzureAD'
          ? {
              enabled: true
              registration: contains(appServiceSlotAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                    openIdIssuer: appServiceSlotAuthSettings.appAuthIdentityProviderOpenIdIssuer[environment]
                  }
                : {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                    openIdIssuer: appServiceSlotAuthSettings.appAuthIdentityProviderOpenIdIssuer.default
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
        facebook: any(appServiceSlotAuthSettings.appAuthIdentityProvider == 'Facebook'
          ? {
              enabled: true
              registration: contains(appServiceSlotAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    appId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId[environment]
                    appSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    appId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId.default
                    appSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              graphApiVersion: appServiceSlotAuthSettings.appAuthIdentityProviderGraphApiVersion
              login: {
                scopes: appServiceSlotAuthSettings.appAuthIdentityProviderScopes
              }
            }
          : null)

        // Github Provider
        gitHub: any(appServiceSlotAuthSettings.appAuthIdentityProvider == 'Github'
          ? {
              enabled: true
              registration: contains(appServiceSlotAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              login: {
                scopes: appServiceSlotAuthSettings.appAuthIdentityProviderScopes
              }
            }
          : null)

        // Google Provider
        google: any(appServiceSlotAuthSettings.appAuthIdentityProvider == 'Google'
          ? {
              enabled: true
              registration: contains(appServiceSlotAuthSettings.appAuthIdentityProviderClientId, environment)
                ? {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId[environment]
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
                : {
                    clientId: appServiceSlotAuthSettings.appAuthIdentityProviderClientId.default
                    clientSecretSettingName: appServiceSlotAuthSettings.appAuthIdentityProviderClientSecretName
                  }
              login: {
                scopes: appServiceSlotAuthSettings.appAuthIdentityProviderScopes
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

// 5. Configure Custom Function Settings (Will use this to disable functions in slots such as: Service Bus Listeners, Timers, etc.,)
module appServiceFunctionSlotFunctionsDeployment 'app-service-slot-function.bicep' = [
  for function in appServiceSlotFunctions: if (!empty(appServiceSlotFunctions) && (appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux')) {
    name: !empty(appServiceSlotFunctions) && (appServiceSlotType == 'functionapp' || appServiceSlotType == 'functionapp,linux')
      ? toLower('app-slot-func-${guid('${appServiceName}/${appServiceSlotName}/${function.name}')}')
      : 'no-func-app/no-function-app-slot-functions-to-deploy'
    scope: resourceGroup()
    params: {
      affix: affix
      region: region
      environment: environment
      appName: appServiceName
      appSlotName: appServiceSlotName
      appSlotFunctionName: function.name
      appSlotFunctionIsDiabled: function.isEnabled
    }
    dependsOn: [
      appServiceSlot
    ]
  }
]

// 7. Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module rbac '../rbac/rbac.bicep' = [
  for appSlotRoleAssignment in appServiceSlotMsiRoleAssignments: if (appServiceSlotMsiEnabled == true && !empty(appServiceSlotMsiRoleAssignments)) {
    name: 'app-slot-rbac-${guid('${appServiceName}-${appServiceSlotName}-${appSlotRoleAssignment.resourceRoleName}')}'
    scope: resourceGroup(replace(
      replace(appSlotRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment),
      '@region',
      region
    ))
    params: {
      affix: affix
      region: region
      environment: environment
      resourceRoleName: appSlotRoleAssignment.resourceRoleName
      resourceToScopeRoleAssignment: appSlotRoleAssignment.resourceToScopeRoleAssignment
      resourceGroupToScopeRoleAssignment: appSlotRoleAssignment.resourceGroupToScopeRoleAssignment
      resourceRoleAssignmentScope: appSlotRoleAssignment.resourceRoleAssignmentScope
      resourceTypeAssigningRole: appSlotRoleAssignment.resourceTypeAssigningRole
      resourcePrincipalIdReceivingRole: appServiceSlot.identity.principalId
    }
  }
]

module privateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(appServiceSlotPrivateEndpoint)) {
  name: !empty(appServiceSlotPrivateEndpoint)
    ? toLower('apps-private-ep-${guid('${appServiceSlot.id}/${appServiceSlotPrivateEndpoint.privateEndpointName}')}')
    : 'no-app-sv-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    privateEndpointName: appServiceSlotPrivateEndpoint.privateEndpointName
    privateEndpointLocation: appServiceSlotPrivateEndpoint.?privateEndpointLocation ?? appServiceSlotLocation
    privateEndpointDnsZoneGroupConfigs: appServiceSlotPrivateEndpoint.privateEndpointDnsZoneGroupConfigs
    privateEndpointVirtualNetworkName: appServiceSlotPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: appServiceSlotPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: appServiceSlotPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: appServiceSlot.id
    privateEndpointTags: appServiceSlotPrivateEndpoint.?privateEndpointTags
    privateEndpointGroupIds: [
      'sites'
    ]
  }
}

// 8. Return Deployment Output
output appServiceSlot object = appServiceSlot
