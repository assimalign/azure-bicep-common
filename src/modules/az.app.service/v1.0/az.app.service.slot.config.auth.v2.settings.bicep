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

@description('The name of the resource group the app lives in')
param appServiceResourceGroup string = resourceGroup().name

@description('')
param appServiceSlotName string 

@allowed([
  'RedirectToLoginPage'
  'AllowAnonymous'
  'Return401'
  'Return403'
])
@description('')
param appServiceSlotAuthUnauthenticatedAction string

@allowed([
  'AzureAD'
  'Github'
  'Facebook'
  'Google'
  'Twitter'
])
@description('')
param appServiceSlotAuthIdentityProviderType string = 'AzureAD'

@description('')
param appServiceSlotAuthIdentityProviderClientId object

@description('')
param appServiceSlotAuthIdentityProviderOpenIdIssuer object 

@description('')
param appServiceSlotAuthIdentityProviderClientSecretName string

@description('')
param appServiceSlotAuthIdentityProviderAudiences array = []

@description('')
param appServiceSlotAuthIdentityProviderScopes array = []

@description('For Facebook')
param appServiceSlotAuthIdentityProviderGraphApiVersion string = ''


var audiences = [for audience in appServiceSlotAuthIdentityProviderAudiences: replace(replace(audience, '@environment', environment), '@region', region)]

// Get the existing app resource 
resource azAppServiceResource 'Microsoft.Web/sites@2021-01-15' existing = {
  name: replace(replace(appServiceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServiceResourceGroup, '@environment', environment), '@region', region))
}

resource azAppServiceAuthSettingsDeployment 'Microsoft.Web/sites/slots/config@2021-01-15' = {
  name: replace(replace('${appServiceName}/${appServiceSlotName}/authsettingsV2', '@environment', environment), '@region', region)
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: appServiceSlotAuthUnauthenticatedAction
    }
    identityProviders: {
      azureActiveDirectory: any(appServiceSlotAuthIdentityProviderType == 'AzureAD' ? {
        enabled: true
        registration: any( environment == 'dev' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceSlotAuthIdentityProviderOpenIdIssuer.dev
        } : any( environment == 'qa' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceSlotAuthIdentityProviderOpenIdIssuer.qa
        } : any( environment == 'uat' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceSlotAuthIdentityProviderOpenIdIssuer.uat
        } : any( environment == 'prd' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceSlotAuthIdentityProviderOpenIdIssuer.prd
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

      facebook: any(appServiceSlotAuthIdentityProviderType == 'Facebook' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          appId: appServiceSlotAuthIdentityProviderClientId.dev
          appSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'qa' ? {
          appId: appServiceSlotAuthIdentityProviderClientId.qa
          appSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'uat' ? {
          appId: appServiceSlotAuthIdentityProviderClientId.uat
          appSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        } : any(environment == 'prd' ? {
          appId: appServiceSlotAuthIdentityProviderClientId.prd
          appSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        } : json('null')))))
        graphApiVersion: appServiceSlotAuthIdentityProviderGraphApiVersion
        login: {
          scopes: appServiceSlotAuthIdentityProviderScopes
        }
      } : json('null'))

      gitHub: any(appServiceSlotAuthIdentityProviderType == 'Github' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appServiceSlotAuthIdentityProviderScopes
        }
      } : json('null'))

      google: any(appServiceSlotAuthIdentityProviderType == 'Google' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appServiceSlotAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceSlotAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appServiceSlotAuthIdentityProviderScopes
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
