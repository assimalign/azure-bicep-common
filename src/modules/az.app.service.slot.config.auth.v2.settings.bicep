@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The Function App Name to be deployed')
param appName string

param appSlotName string 

@description('The name of the resource group the app lives in')
param appResourceGroup string = resourceGroup().name

@allowed([
  'RedirectToLoginPage'
  'AllowAnonymous'
  'Return401'
  'Return403'
])
@description('')
param appSlotAuthUnauthenticatedAction string

@allowed([
  'AzureAD'
  'Github'
  'Facebook'
  'Google'
  'Twitter'
])
@description('')
param appSlotAuthIdentityProviderType string = 'AzureAD'

@description('')
param appSlotAuthIdentityProviderClientId object

@description('')
param appSlotAuthIdentityProviderOpenIdIssuer object 

@description('')
param appSlotAuthIdentityProviderClientSecretName string

@description('')
param appSlotAuthIdentityProviderAudiences array = []

@description('')
param appSlotAuthIdentityProviderScopes array = []

@description('For Facebook')
param appSlotAuthIdentityProviderGraphApiVersion string = ''


var audiences = [for audience in appSlotAuthIdentityProviderAudiences: replace(replace(audience, '@environment', environment), '@location', location)]

// Get the existing app resource 
resource azAppServiceResource 'Microsoft.Web/sites@2021-01-15' existing = {
  name: replace(replace(appName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appResourceGroup, '@environment', environment), '@location', location))
}

resource azAppServiceAuthSettingsDeployment 'Microsoft.Web/sites/slots/config@2021-01-15' = {
  name: replace(replace('${appName}/${appSlotName}/authsettingsV2', '@environment', environment), '@location', location)
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: appSlotAuthUnauthenticatedAction
    }
    identityProviders: {
      azureActiveDirectory: any(appSlotAuthIdentityProviderType == 'AzureAD' ? {
        enabled: true
        registration: any( environment == 'dev' ? {
          clientId: appSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appSlotAuthIdentityProviderOpenIdIssuer.dev
        } : any( environment == 'qa' ? {
          clientId: appSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appSlotAuthIdentityProviderOpenIdIssuer.qa
        } : any( environment == 'uat' ? {
          clientId: appSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appSlotAuthIdentityProviderOpenIdIssuer.uat
        } : any( environment == 'prd' ? {
          clientId: appSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appSlotAuthIdentityProviderOpenIdIssuer.prd
        } : json('null')))))
        validation: {
          allowedAudiences: union([
            'https://${azAppServiceResource.properties.defaultHostName}'
          ], audiences) 
        }
        isAutoProvisioned: false
        login: {
          tokenStore: {
            enabled: true
          }
        }
      } : json('null'))

      facebook: any(appSlotAuthIdentityProviderType == 'Facebook' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          appId: appSlotAuthIdentityProviderClientId.dev
          appSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'qa' ? {
          appId: appSlotAuthIdentityProviderClientId.qa
          appSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'uat' ? {
          appId: appSlotAuthIdentityProviderClientId.uat
          appSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'prd' ? {
          appId: appSlotAuthIdentityProviderClientId.prd
          appSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        } : json('null')))))
        graphApiVersion: appSlotAuthIdentityProviderGraphApiVersion
        login: {
          scopes: appSlotAuthIdentityProviderScopes
        }
      } : json('null'))

      gitHub: any(appSlotAuthIdentityProviderType == 'Github' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appSlotAuthIdentityProviderScopes
        }
      } : json('null'))

      google: any(appSlotAuthIdentityProviderType == 'Google' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appSlotAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appSlotAuthIdentityProviderScopes
        }
        validation: {
          allowedAudiences: union([
            'https://${azAppServiceResource.properties.defaultHostName}'
          ], audiences)
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
