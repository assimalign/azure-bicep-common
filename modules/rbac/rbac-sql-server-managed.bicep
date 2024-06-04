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

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

// A collection of available roles to assign to service principals for SQL Server Managed Instance
var RoleDefinitionId = {
  SQLManagedInstanceContributor: '4939a1f6-9ae0-4e48-a1e0-f2cbe897382d'
}


// 1. If applicable, get existing Sql Server Managed instance to scope role assignment to
resource azSqlServerManagedExistingResource 'Microsoft.Sql/managedInstances@2021-02-01-preview' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(replace(resourceToScopeRoleAssignment, '@affix', affix), '@environment', environment), '@region', region)
}

// 2. Assign Resource Role Scoped to the resource
resource azSqlServerManagedResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid(resourcePrincipalIdReceivingRole, RoleDefinitionId[resourceRoleName], 'scope-resource')
  scope: azSqlServerManagedExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azSqlServerManagedResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid(resourcePrincipalIdReceivingRole, RoleDefinitionId[resourceRoleName], 'scope-resource-group')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
