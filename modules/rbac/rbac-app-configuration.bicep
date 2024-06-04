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

// A collection of available roles to assign to service principals for App Configuration
var RoleDefinitionId = {
  AppConfigurationDataOwner: '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
  AppConfigurationDataReader: '516239f1-63e1-4d78-a4de-a74fb236a071'
}

// 1. Get an existing resource to scope the resource role assignment to, if applicable
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(replace(resourceToScopeRoleAssignment, '@affix', affix), '@environment', environment), '@region', region)
}

// 2. Assign Resource Role Scoped to the resource
resource appConfigScopedRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid(resourcePrincipalIdReceivingRole, RoleDefinitionId[resourceRoleName],'scope-resource')
  scope: appConfig
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource appConfigGroupRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid(resourcePrincipalIdReceivingRole, RoleDefinitionId[resourceRoleName], 'scope-resource-group')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
