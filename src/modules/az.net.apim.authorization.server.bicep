@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the API Management resource')
param apimName string

@description('')
param apimApiName string




resource azApimAuthorizationPolicyDeployment 'Microsoft.ApiManagement/service/authorizationServers@2021-01-01-preview' = {
  name: replace('${apimName}/${apimApiName}', '@environment', environment)
  properties: {
   
  }
}

