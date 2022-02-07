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




resource azApimAuthorizationPolicyDeployment 'Microsoft.ApiManagement/service/authorizationServers@2021-01-01-preview' = {
  name: replace(replace('${apimName}/${apimApiName}', '@environment', environment), '@location', location)
  properties: {
   
  }
}

