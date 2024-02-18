@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The location prefix or suffix for the resource name')
param region string = ''

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

resource apimApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: replace(replace('${apimGatewayName}/${apimGatewayApiName}', '@environment', environment), '@region', region)
  properties: {
    path: replace(replace(contains(apimGatewayApiPath, environment) ? apimGatewayApiPath[environment] : apimGatewayApiPath.default, '@environment', environment), '@region', region)
    protocols: apimGatewayApiProtocols
    isCurrent: true
    subscriptionRequired: apimGatewayApiSubscriptionRequired
    apiType: apimGatewayApiType
    description: apimGatewayApiDescription
    displayName: replace(replace(apimGatewayApiName, '@environment', environment), '@region', region)
    authenticationSettings: empty(apimGatewayApiAuthenticationConfigs) ? null : apimGatewayApiAuthenticationConfigs.authenticationType == 'OpenIDConnect' ? {
      openid: {
        bearerTokenSendingMethods: [
          apimGatewayApiAuthenticationConfigs.authenticationOpenIDConnectionSendingMethod
        ]
        openidProviderId: apimGatewayApiAuthenticationConfigs.authenticationOpenIDConnectionReferenceName
      }
    } : {
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
    value: replace(replace(apimGatewayApiPolicy, '@environment', environment), '@region', region)
    format: 'xml'
  }
}

module apimApiOperation 'apimApiOperation.bicep' = [for operation in apimGatewayApiOperations: if (!empty(apimGatewayApiOperations)) {
  name: 'apim-api-operation-${guid(replace(replace('${!empty(apimGatewayApiOperations) ? operation.apimGatewayApiOperationName : 'no-az-apim-operation'}', '', ''), '', ''))}'
  params: {
    region: region
    environment: environment
    apimGatewayName: apimGatewayName
    apimGatewayApiName: apimGatewayApiName
    apimGatewayApiOperationName: operation.apimGatewayApiOperationName
    apimGatewayApiOperationDisplayName: operation.apimGatewayApiOperationDisplayName
    apimGatewayApiOperationMethod: operation.apimGatewayApiOperationMethod
    apimGatewayApiOperationUrlTemplate: operation.apimApiOperationUrlTemplate
    apimGatewayApiOperationDescription: contains(operation, 'apimGatewayApiOperationDescription') ? operation.apimGatewayApiOperationDescription : ''
    apimGatewayApiOperationUrlTemplateParameters: contains(operation, 'apimGatewayApiOperationUrlTemplateParameters') ? operation.apimGatewayApiOperationUrlTemplateParameters : []
    apimGatewayApiOperationRequestHeaders: contains(operation, 'apimGatewayApiOperationRequestHeaders') ? operation.apimGatewayApiOperationRequestHeaders : []
    apimGatewayApiOperationRequestQueryParameters: contains(operation, 'apimGatewayApiOperationRequestQueryParameters') ? operation.apimGatewayApiOperationRequestQueryParameters : []
    apimGatewayApiOperationPolicy: contains(operation, 'apimGatewayApiOperationPolicy') ? operation.apimGatewayApiOperationPolicy : ''
  }
  dependsOn: [
    apimApiPolicies
    apimApi
  ]
}]

output apimGatewayApi object = apimApi
