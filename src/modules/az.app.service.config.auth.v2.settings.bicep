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

@description('The name of the resource group the app lives in')
param appResourceGroup string = resourceGroup().name

@allowed([
  'RedirectToLoginPage'
  'AllowAnonymous'
  'Return401'
  'Return403'
])
@description('')
param appAuthUnauthenticatedAction string

@allowed([
  'AzureAD'
  'Github'
  'Facebook'
  'Google'
  'Twitter'
])
@description('')
param appAuthIdentityProviderType string = 'AzureAD'

@description('')
param appAuthIdentityProviderClientId object

@description('')
param appAuthIdentityProviderOpenIdIssuer object 

@description('')
param appAuthIdentityProviderClientSecretName string

@description('')
param appAuthIdentityProviderAudiences array = []

@description('')
param appAuthIdentityProviderScopes array = []

@description('The Graph API Version provider is for Facebook identity provider only')
param appAuthIdentityProviderGraphApiVersion string = ''


// Get the existing app resource 
resource azAppServiceResource 'Microsoft.Web/sites@2021-01-15' existing = {
  name: replace(replace(appName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appResourceGroup, '@environment', environment), '@location', location))
}

resource azAppServiceAuthSettingsDeployment 'Microsoft.Web/sites/config@2021-01-15' = {
  name: replace(replace('${appName}/authsettingsV2', '@environment', environment), '@location', location)
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: appAuthUnauthenticatedAction
    }
    identityProviders: {
      azureActiveDirectory: any(appAuthIdentityProviderType == 'AzureAD' ? {
        enabled: true
        registration: any( environment == 'dev' ? {
          clientId: appAuthIdentityProviderClientId.dev
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
          openIdIssuer: appAuthIdentityProviderOpenIdIssuer.dev
        } : any( environment == 'qa' ? {
          clientId: appAuthIdentityProviderClientId.qa
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
          openIdIssuer: appAuthIdentityProviderOpenIdIssuer.qa
        } : any( environment == 'uat' ? {
          clientId: appAuthIdentityProviderClientId.uat
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
          openIdIssuer: appAuthIdentityProviderOpenIdIssuer.uat
        } : any( environment == 'prd' ? {
          clientId: appAuthIdentityProviderClientId.prd
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
          openIdIssuer: appAuthIdentityProviderOpenIdIssuer.prd
        } : json('null')))))
        validation: {
          allowedAudiences: union([
            'https://${azAppServiceResource.properties.defaultHostName}'
          ],appAuthIdentityProviderAudiences) 
        }
        isAutoProvisioned: false
        login: {
          tokenStore: {
            enabled: true
          }
        }
      } : json('null'))

      facebook: any(appAuthIdentityProviderType == 'Facebook' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          appId: appAuthIdentityProviderClientId.dev
          appSecretSettingName: appAuthIdentityProviderClientSecretName
        } : any(environment == 'qa' ? {
          appId: appAuthIdentityProviderClientId.qa
          appSecretSettingName: appAuthIdentityProviderClientSecretName
        } : any(environment == 'uat' ? {
          appId: appAuthIdentityProviderClientId.uat
          appSecretSettingName: appAuthIdentityProviderClientSecretName
        } : any(environment == 'prd' ? {
          appId: appAuthIdentityProviderClientId.prd
          appSecretSettingName: appAuthIdentityProviderClientSecretName
        } : json('null')))))
        graphApiVersion: appAuthIdentityProviderGraphApiVersion
        login: {
          scopes: appAuthIdentityProviderScopes
        }
      } : json('null'))

      gitHub: any(appAuthIdentityProviderType == 'Github' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appAuthIdentityProviderClientId.dev
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appAuthIdentityProviderClientId.qa
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appAuthIdentityProviderClientId.uat
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appAuthIdentityProviderClientId.prd
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appAuthIdentityProviderScopes
        }
      } : json('null'))

      google: any(appAuthIdentityProviderType == 'Google' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appAuthIdentityProviderClientId.dev
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appAuthIdentityProviderClientId.qa
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appAuthIdentityProviderClientId.uat
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appAuthIdentityProviderClientId.prd
          clientSecretSettingName: appAuthIdentityProviderClientSecretName
        }: json('null')))))
        login: {
          scopes: appAuthIdentityProviderScopes
        }
        validation: {
          allowedAudiences: union([
            'https://${azAppServiceResource.properties.defaultHostName}'
          ],appAuthIdentityProviderAudiences)
        }
      } : json('null'))

      // twitter: {
      //   enabled: boolean
      //   registration: {
      //     consumerKey: string
      //     consumerSecretSettingName: string
      //   }
      // }
      // customOpenIdConnectProviders: {
      //   enabled: boolean
      //   registration: {
      //     clientId: string
      //     clientCredential: {
      //       method: string
      //     }
      //     clientSecretSettingName: string
      //     openIdConnectConfiguration: {
      //       authorizationEndpoint: string
      //       tokenEndpoint: string
      //       issuer: string
      //       certificationUri: string
      //       wellKnownOpenIdConfiguration: string
      //     }
      //   }
      //   login: {
      //     tokenStore: {
      //       enabled: true
      //     }
      //   }
      // }
    }
    login: {
      // routes: {
      //   logoutEndpoint: 'string'
      // }
      tokenStore: {
        enabled: true
      }
    }
    // httpSettings: {
    //   requireHttps: bool
    //   routes: {
    //     apiPrefix: 'string'
    //   }
    //   forwardProxy: {
    //     convention: 'string'
    //     customHostHeaderName: 'string'
    //     customProtoHeaderName: 'string'
    //   }
    // }
  }
}
