@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

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
param resourcePrincipalIdRecievingRole string

@description('If scoping resource role assignment to a specific the resource the name of the resource must be specified')
param resourceToScopeRoleAssignment string = ''


var RoleDefinitionId = {
  EventGridContributor: '1e241071-0855-49ea-94dc-649edcd759de'
  EventGridDataSender: 'd5a91429-5739-47e2-a06b-3470a27159e7'
  EventGridEventSubscriptionContributor: '428e0ff0-5e57-4d9c-a221-2c70d0e0a443'
  EventGridEventSubscriptionReader: '2414bbcf-6497-4faf-8c65-045460748405'
}


// 1. Get an existing resource to scope the resource role assignment to, if applicable
resource azKeyVaultExistingResource 'Microsoft.EventGrid/domains@2021-06-01-preview' existing = if(resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}


// 2. Assign Resource Role Scoped to the Resource
resource azKeyVaultResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azKeyVaultExistingResource
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}


// 3. Assign Resource Role Scoped to the Resource Group
resource azKeyVaultResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
