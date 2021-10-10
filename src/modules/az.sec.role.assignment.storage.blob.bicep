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
  StorageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  StorageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDelegator: 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'
}


resource azStorageAccountBlobContainerExistingResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' existing = if(resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}


// 2. Assign Resource Role Scoped to the resource
resource azStorageAccountBlobContainerResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azStorageAccountBlobContainerExistingResource
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}


// 3. Assign Resource Role Scoped to the Resource Group
resource azStorageAccountBlobContainerResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
