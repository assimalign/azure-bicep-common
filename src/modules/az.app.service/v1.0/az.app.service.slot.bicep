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

@description('The settings for the app service deployment')
param appServiceSlotSiteConfigs object

@description('Custom Attributes to attach to the app service deployment')
param appServiceSlotTags object = {}

// Format Site Settings 
var siteSettings = [for item in items(contains(appServiceSlotSiteConfigs, 'siteSettings') ? appServiceSlotSiteConfigs.siteSettings : {}): {
  name: replace(replace(item.key, '@environment', environment), '@region', region)
  value: replace(replace(sys.contains(item.value, environment) ? item.value[environment] : item.value.default, '@environment', environment), '@region', region)
}]

// Formt auth settings if any
var authSettingsAudienceValues = contains(appServiceSlotSiteConfigs, 'authSettings') ? contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences, environment) ? appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences[environment] : appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderAudiences.default : []
var authSettingAudiences = [for audience in authSettingsAudienceValues: replace(replace(audience, '@environment', environment), '@region', region)]

// 1. Get the existing App Service Plan to attach to the 
// Note: All web service (Function & Web Apps) have App Service Plans even if it is consumption Y1 Plans
resource azAppServicePlanResource 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: replace(replace(appServiceSlotPlanName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotPlanResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get existing app storage account resource
resource azAppServiceStorageResource 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: replace(replace(appServiceSlotStorageAccountName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotStorageAccountResourceGroup, '@environment', environment), '@region', region))
}

// 3. Get existing app insights 
resource azAppServiceInsightsResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: replace(replace(appServiceSlotInsightsName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceSlotInsightsResourceGroup, '@environment', environment), '@region', region))
}

// 4.1 Deploy Function App, if applicable
resource azAppServiceSlotDeployment 'Microsoft.Web/sites/slots@2022-03-01' = {
  name: replace(replace('${appServiceName}/${appServiceSlotName}', '@environment', environment), '@region', region)
  location: appServiceSlotLocation
  kind: appServiceSlotType
  identity: {
    type: appServiceSlotMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: azAppServicePlanResource.id
    httpsOnly: contains(appServiceSlotSiteConfigs, 'webSettings') && contains(appServiceSlotSiteConfigs.webSettings, 'httpsOnly') ? appServiceSlotSiteConfigs.webSettings.httpsOnly : false
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: contains(appServiceSlotSiteConfigs, 'alwaysOn') ? appServiceSlotSiteConfigs.alwaysOn : false
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
        ], siteSettings)
    }
  }
  tags: union(appServiceSlotTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })

  resource azAppServiceLinkApim 'config' = if (contains(appServiceSlotSiteConfigs, 'webSettings')) {
    name: 'web'
    properties: {
      cors: contains(appServiceSlotSiteConfigs.webSettings, 'cors') ? appServiceSlotSiteConfigs.webSettings.cors : {}
      ftpsState: contains(appServiceSlotSiteConfigs.webSettings, 'ftpsState') ? appServiceSlotSiteConfigs.webSettings.ftpsState : 'FtpsOnly'
      alwaysOn: contains(appServiceSlotSiteConfigs.webSettings, 'alwaysOn') ? appServiceSlotSiteConfigs.webSettings.alwaysOn : false
      phpVersion: contains(appServiceSlotSiteConfigs.webSettings, 'phpVersion') ? appServiceSlotSiteConfigs.webSettings.phpVersion : null
      nodeVersion: contains(appServiceSlotSiteConfigs.webSettings, 'nodeVersion') ? appServiceSlotSiteConfigs.webSettings.nodeVersion : null
      javaVersion: contains(appServiceSlotSiteConfigs.webSettings, 'javaVersion') ? appServiceSlotSiteConfigs.webSettings.javaVersion : null
      pythonVersion: contains(appServiceSlotSiteConfigs.webSettings, 'pythonVersion') ? appServiceSlotSiteConfigs.webSettings.pythonVersion : null
      netFrameworkVersion: contains(appServiceSlotSiteConfigs.webSettings, 'dotnetVersion') ? appServiceSlotSiteConfigs.webSettings.dotnetVersion : null
      apiManagementConfig: any(contains(appServiceSlotSiteConfigs.webSettings, 'apimGateway') ? {
        id: any(replace(replace(resourceId(appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayResourceGroup, 'Microsoft.ApiManagement/service/apis', appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayName, appServiceSlotSiteConfigs.webSettings.apimGateway.apimGatewayApiName), '@environment', environment), '@region', region))
      } : {})
    }
  }
  resource azAppServiceMetadataConfigs 'config' = if (contains(appServiceSlotSiteConfigs, 'metaSettings')) {
    name: 'metadata'
    properties: appServiceSlotSiteConfigs.metaSettings
  }
  resource azAppServiceAuthSettings 'config' = if (contains(appServiceSlotSiteConfigs, 'authSettings')) {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: appServiceSlotSiteConfigs.authSettings.appAuthUnauthenticatedAction
      }
      identityProviders: {
        // Azure Active Directory Provider
        azureActiveDirectory: any(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProvider == 'AzureAD' ? {
          enabled: true
          registration: contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
            openIdIssuer: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderOpenIdIssuer[environment]
          } : {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
            openIdIssuer: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderOpenIdIssuer.default
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
        } : json('null'))

        // Facebook Provider
        facebook: any(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProvider == 'Facebook' ? {
          enabled: true
          registration: contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            appId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            appSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            appId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            appSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          graphApiVersion: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderGraphApiVersion
          login: {
            scopes: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
        } : json('null'))

        // Github Provider
        gitHub: any(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProvider == 'Github' ? {
          enabled: true
          registration: contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          login: {
            scopes: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
        } : json('null'))

        // Google Provider
        google: any(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProvider == 'Google' ? {
          enabled: true
          registration: contains(appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId, environment) ? {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId[environment]
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          } : {
            clientId: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientId.default
            clientSecretSettingName: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderClientSecretName
          }
          login: {
            scopes: appServiceSlotSiteConfigs.authSettings.appAuthIdentityProviderScopes
          }
          validation: {
            allowedAudiences: authSettingAudiences
          }
        } : json('null'))
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
    azAppServiceSlotDeployment
  ]
}]

// 7. Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azAppServiceSlotFunctionRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for appSlotRoleAssignment in appServiceSlotMsiRoleAssignments: if (appServiceSlotMsiEnabled == true && !empty(appServiceSlotMsiRoleAssignments)) {
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
    resourcePrincipalIdReceivingRole: azAppServiceSlotDeployment.identity.principalId
  }
}]

// 8. Return Deployment Output
output appServiceSlot object = azAppServiceSlotDeployment
