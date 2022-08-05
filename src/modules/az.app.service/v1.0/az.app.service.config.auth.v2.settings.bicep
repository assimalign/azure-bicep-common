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
  'RedirectToLoginPage'
  'AllowAnonymous'
  'Return401'
  'Return403'
])
@description('')
param appServiceAuthUnauthenticatedAction string

@allowed([
  'AzureAD'
  'Github'
  'Facebook'
  'Google'
  'Twitter'
])
@description('The identity provider issuign the Oath token')
param appServiceAuthIdentityProviderType string = 'AzureAD'

@description('The Client Id associated with the identity provider')
param appServiceAuthIdentityProviderClientId object

@description('The issuer for the security token')
param appServiceAuthIdentityProviderOpenIdIssuer object 

@description('')
param appServiceAuthIdentityProviderClientSecretName string

@description('')
param appServiceAuthIdentityProviderAudiences object = {}

@description('')
param appServiceAuthIdentityProviderScopes array = []

@description('For Facebook')
param appServiceAuthIdentityProviderGraphApiVersion string = ''


var audience = !empty(appServiceAuthIdentityProviderAudiences) ? environment == 'dev' ?  {
  values: appServiceAuthIdentityProviderAudiences.dev
} : environment == 'qa' ?  {
  values: appServiceAuthIdentityProviderAudiences.qa
} :environment == 'uat' ?  {
  values: appServiceAuthIdentityProviderAudiences.uat
} :environment == 'prd' ?  {
  values: appServiceAuthIdentityProviderAudiences.prd
} : {
  values: appServiceAuthIdentityProviderAudiences.default
} : {
  values: []
}
var audiences = [for value in audience.values: replace(replace(value, '@environment', environment), '@region', region)]

resource azAppServiceAuthSettingsDeployment 'Microsoft.Web/sites/config@2022-03-01' = {
  name: replace(replace('${appServiceName}/authsettingsV2', '@environment', environment), '@region', region)
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: appServiceAuthUnauthenticatedAction
    }
    identityProviders: {
      azureActiveDirectory: any(appServiceAuthIdentityProviderType == 'AzureAD' ? {
        enabled: true
        registration: any( environment == 'dev' ? {
          clientId: appServiceAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceAuthIdentityProviderOpenIdIssuer.dev
        } : any( environment == 'qa' ? {
          clientId: appServiceAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceAuthIdentityProviderOpenIdIssuer.qa
        } : any( environment == 'uat' ? {
          clientId: appServiceAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceAuthIdentityProviderOpenIdIssuer.uat
        } : any( environment == 'prd' ? {
          clientId: appServiceAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceAuthIdentityProviderOpenIdIssuer.prd
        } : {
          clientId: appServiceAuthIdentityProviderClientId.default
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
          openIdIssuer: appServiceAuthIdentityProviderOpenIdIssuer.default
        }))))
        validation: {
          allowedAudiences: audiences
        }
        isAutoProvisioned: false
        login: {
          tokenStore: {
            enabled: true
          }
        }
      } : json('null'))

      facebook: any(appServiceAuthIdentityProviderType == 'Facebook' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          appId: appServiceAuthIdentityProviderClientId.dev
          appSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        } : any(environment == 'qa' ? {
          appId: appServiceAuthIdentityProviderClientId.qa
          appSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        } : any(environment == 'uat' ? {
          appId: appServiceAuthIdentityProviderClientId.uat
          appSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        } : any(environment == 'prd' ? {
          appId: appServiceAuthIdentityProviderClientId.prd
          appSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        } : {
          appId: appServiceAuthIdentityProviderClientId.default
          appSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }))))
        graphApiVersion: appServiceAuthIdentityProviderGraphApiVersion
        login: {
          scopes: appServiceAuthIdentityProviderScopes
        }
      } : json('null'))

      gitHub: any(appServiceAuthIdentityProviderType == 'Github' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appServiceAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appServiceAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appServiceAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appServiceAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: {
          clientId: appServiceAuthIdentityProviderClientId.default
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }))))
        login: {
          scopes: appServiceAuthIdentityProviderScopes
        }
      } : json('null'))

      google: any(appServiceAuthIdentityProviderType == 'Google' ? {
        enabled: true
        registration: any(environment == 'dev' ? {
          clientId: appServiceAuthIdentityProviderClientId.dev
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'qa' ? {
          clientId: appServiceAuthIdentityProviderClientId.qa
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'uat' ? {
          clientId: appServiceAuthIdentityProviderClientId.uat
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: any(environment == 'prd' ? {
          clientId: appServiceAuthIdentityProviderClientId.prd
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }: {
          clientId: appServiceAuthIdentityProviderClientId.default
          clientSecretSettingName: appServiceAuthIdentityProviderClientSecretName
        }))))
        login: {
          scopes: appServiceAuthIdentityProviderScopes
        }
        validation: {
          allowedAudiences: audiences
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
