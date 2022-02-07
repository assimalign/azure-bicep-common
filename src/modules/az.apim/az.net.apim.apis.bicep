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

@description('The name of the API Management resource')
param apimName string

@description('')
param apimApiName string

@description('')
param apimApiDescription string = ''

@description('')
param apimApiProtocols array = [
  'https'
]

@description('')
param apimApiPath string

@description('')
param apimApiSubscriptionRequired bool = true

@description('')
param apimApiPolicies string = ''

@description('')
param apimApiOperations array = []




resource azApimApiDeployment 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: replace(replace('${apimName}/${apimApiName}', '@environment', environment), '@location', location)
  properties: {
    path: replace(replace(apimApiPath, '@environment', environment), '@location', location)
    protocols: apimApiProtocols
    isCurrent: true
    subscriptionRequired: apimApiSubscriptionRequired
    apiType: 'http'
    description: apimApiDescription
    displayName: replace(replace(apimApiName, '@environment', environment), '@location', location)     
  }
}

resource azApimApiPoliciesDeployment 'Microsoft.ApiManagement/service/apis/policies@2020-12-01' = if (!empty(apimApiPolicies)) {
 name: 'policy'
 parent: azApimApiDeployment
 properties: {
   value: replace(replace(apimApiPolicies, '@environment', environment), '@location', location)
    format: 'xml'
 }
 dependsOn: [
  azApimApiDeployment
 ]
}

module azApimApiOperationDeployment 'az.net.apim.apis.operation.bicep' = [for operation in apimApiOperations: if (!empty(apimApiOperations)) {
  name: !empty(apimApiOperations) ? 'az-apim-operation-${guid(operation.apimApiOperationName)}' : 'no-apim-api-operation-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    apimName: apimName
    apimApiName: apimApiName
    apimApiOperationName: operation.apimApiOperationName
    apimApiOperationDisplayName: operation.apimApiOperationDisplayName
    apimApiOperationMethod: operation.apimApiOperationMethod
    apimApiOperationDescription: operation.apimApiOperationDescription
    apimApiOperationUrlTemplate: operation.apimApiOperationUrlTemplate
    apimApiOperationParametersTemplate: operation.apimApiOperationTemplateParameters
  }
  dependsOn: [
    azApimApiPoliciesDeployment
    azApimApiDeployment
  ]
}]
