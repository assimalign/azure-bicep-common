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

@description('The location prefix or suffix for the resource name')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the API Management resource')
param apimGatewayName string

@description('')
param apimGatewayApiName string

@description('')
param apimGatewayApiDescription string = ''

@description('')
param apimGatewayApiProtocols array = [
  'https'
]

@description('')
param apimGatewayApiType string = 'http'

@description('The suffix to be tacket on to the endpoint of the endpoint.')
param apimGatewayApiPath object

@description('')
param apimGatewayApiSubscriptionRequired bool = true

@description('The policy or policies to be set for all API Operations')
param apimGatewayApiPolicy string = ''

@description('A collection of API Operations.')
param apimGatewayApiOperations array = []

@description('')
param apimGatewayApiAuthenticationConfigs object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource apimApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: formatName('${apimGatewayName}/${apimGatewayApiName}', affix, environment, region)
  properties: {
    path: formatName(
      contains(apimGatewayApiPath, environment) ? apimGatewayApiPath[environment] : apimGatewayApiPath.default,
      affix,
      environment,
      region
    )
    protocols: apimGatewayApiProtocols
    isCurrent: true
    subscriptionRequired: apimGatewayApiSubscriptionRequired
    apiType: apimGatewayApiType
    description: apimGatewayApiDescription
    displayName: formatName(apimGatewayApiName, affix, environment, region)
    authenticationSettings: empty(apimGatewayApiAuthenticationConfigs)
      ? null
      : apimGatewayApiAuthenticationConfigs.authenticationType == 'OpenIDConnect'
          ? {
              openid: {
                bearerTokenSendingMethods: [
                  apimGatewayApiAuthenticationConfigs.authenticationOpenIDConnectionSendingMethod
                ]
                openidProviderId: apimGatewayApiAuthenticationConfigs.authenticationOpenIDConnectionReferenceName
              }
            }
          : {
              oAuth2: {
                authorizationServerId: apimGatewayApiAuthenticationConfigs.authenticationOAthReferenceName
                scope: apimGatewayApiAuthenticationConfigs.authenticationOAuthScope
              }
            }
  }
}

resource apimApiPolicies 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = if (!empty(apimGatewayApiPolicy)) {
  name: 'policy'
  parent: apimApi
  properties: {
    value: formatName(apimGatewayApiPolicy, affix, environment, region)
    format: 'xml'
  }
}

module apimApiOperation 'apim-api-operation.bicep' = [
  for operation in apimGatewayApiOperations: if (!empty(apimGatewayApiOperations)) {
    name: 'apim-api-operation-${guid(replace(replace('${!empty(apimGatewayApiOperations) ? operation.apimGatewayApiOperationName : 'no-az-apim-operation'}', '', ''), '', ''))}'
    params: {
      affix: affix
      region: region
      environment: environment
      apimGatewayName: apimGatewayName
      apimGatewayApiName: apimGatewayApiName
      apimGatewayApiOperationName: operation.apimGatewayApiOperationName
      apimGatewayApiOperationDisplayName: operation.apimGatewayApiOperationDisplayName
      apimGatewayApiOperationMethod: operation.apimGatewayApiOperationMethod
      apimGatewayApiOperationUrlTemplate: operation.apimApiOperationUrlTemplate
      apimGatewayApiOperationDescription: operation.?apimGatewayApiOperationDescription
      apimGatewayApiOperationUrlTemplateParameters: operation.?apimGatewayApiOperationUrlTemplateParameters
      apimGatewayApiOperationRequestHeaders: operation.?apimGatewayApiOperationRequestHeaders
      apimGatewayApiOperationRequestQueryParameters: operation.?apimGatewayApiOperationRequestQueryParameters
      apimGatewayApiOperationPolicy: operation.?apimGatewayApiOperationPolicy
    }
    dependsOn: [
      apimApiPolicies
      apimApi
    ]
  }
]

output apimGatewayApi object = apimApi
