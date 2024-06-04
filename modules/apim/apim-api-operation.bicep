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
param apimGatewayApiOperationName string

@description('')
param apimGatewayApiOperationDisplayName string

@allowed([
   'GET'
   'PUT'
   'POST'
   'DELETE'
   'PATCH'
])
@description('')
param apimGatewayApiOperationMethod string

@description('')
param apimGatewayApiOperationDescription string = ''

@description('')
param apimGatewayApiOperationUrlTemplate string

@description('')
param apimGatewayApiOperationUrlTemplateParameters array = []

@description('')
param apimGatewayApiOperationRequestQueryParameters array = []

@description('')
param apimGatewayApiOperationRequestHeaders array = []

@description('')
param apimGatewayApiOperationPolicy string = ''

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource azApimApiOperationDeployment 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
   name: formatName('${apimGatewayName}/${apimGatewayApiName}/${apimGatewayApiOperationName}', affix, environment, region)
   properties: {
      policies: empty(apimGatewayApiOperationPolicy) ? null : apimGatewayApiOperationPolicy
      displayName: apimGatewayApiOperationDisplayName
      urlTemplate: apimGatewayApiOperationUrlTemplate
      method: apimGatewayApiOperationMethod
      description: apimGatewayApiOperationDescription
      templateParameters: apimGatewayApiOperationUrlTemplateParameters
      request: any(!empty(apimGatewayApiOperationRequestQueryParameters) || !empty(apimGatewayApiOperationRequestHeaders) ? {
         headers: apimGatewayApiOperationRequestHeaders
         queryParameters: apimGatewayApiOperationRequestQueryParameters
      } : null)
   }
}

output apimGatewayApiOperation object = azApimApiOperationDeployment
