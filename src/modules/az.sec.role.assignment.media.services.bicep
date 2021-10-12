@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix for the resource name')
param location string = ''

@description('The name of the resource role to assign to the service principal')
param resourceRoleName string

@allowed([
  'Resource'
  'ResourceGroup'
])
@description('The assignment scope for the role assignment. Currently Supports assigning roles at the resource level or subscription level')
param resourceRoleAssignmentScope string = 'ResourceGroup'

@description('The principal Id reciving the role assignment')
param resourcePrincipalIdReceivingRole string

@description('If scoping resource role assignment to a specific the resource the name of the resource must be specified')
param resourceToScopeRoleAssignment string = ''

// A collection of available roles to assign to service principals for Media Services
var RoleDefinitionId = {
  MediaServicesAccountAdministrator: '054126f8-9a2b-4f1c-a9ad-eca461f08466'
  MediaServicesLiveEventsAdministrator: '532bc159-b25e-42c0-969e-a1d439f60d77'
  MediaServicesMediaOperator: 'e4395492-1534-4db2-bedf-88c14621589c'
  MediaServicesPolicyAdministrator: 'c4bba371-dacd-4a26-b320-7250bca963ae'
  MediaServicesStreamingEndpointsAdministrator: '99dba123-b5fe-44d5-874c-ced7199a5804'
}

// 1. If applicable, get existing media services resource to scope role assignment
resource azMediaServicesExistingResource 'Microsoft.Media/mediaservices@2021-06-01' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}

// 2. Assign Resource Role Scoped to the resource
resource azMediaServicesResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azMediaServicesExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azMediaServicesResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
