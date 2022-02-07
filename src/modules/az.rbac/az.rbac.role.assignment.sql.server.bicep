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

// A collection of available roles to assign to service principals for SQL Server
var RoleDefinitionId = {
  SQLDBContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
  SQLSecurityManager: '056cd41c-7e88-42e1-933e-88ba6a50c9c3'
  SQLServerContributor: '6d8ee4ec-f05a-4a1d-8b00-a9b17e38b437'
}


// 1. If applicable, get existing Sql Server Instance to scope role assignment to
resource azSqlServerExistingResource 'Microsoft.Sql/servers@2021-02-01-preview' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}

// 2. Assign Resource Role Scoped to the resource
resource azSqlServerResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azSqlServerExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azSqlServerResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
