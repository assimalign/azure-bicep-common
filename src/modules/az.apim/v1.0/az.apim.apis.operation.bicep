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
param apimName string

@description('')
param apimApiName string

@description('')
param apimApiOperationName string

@description('')
param apimApiOperationDisplayName string

@allowed([
   'GET'
   'PUT'
   'POST'
   'DELETE'
   'PATCH'
])
@description('')
param apimApiOperationMethod string

@description('')
param apimApiOperationDescription string = ''

@description('')
param apimApiOperationUrlTemplate string

@description('')
param apimApiOperationParametersTemplate array = []

resource azApimApiOperationDeployment 'Microsoft.ApiManagement/service/apis/operations@2021-01-01-preview' = {
   name: replace(replace('${apimName}/${apimApiName}/${apimApiOperationName}', '@environment', environment), '@region', region)
   properties: {
      displayName: apimApiOperationDisplayName
      urlTemplate: apimApiOperationUrlTemplate
      method: apimApiOperationMethod
      description: apimApiOperationDescription
      templateParameters: apimApiOperationParametersTemplate
   }
}

output apimApiOperation object = azApimApiOperationDeployment
