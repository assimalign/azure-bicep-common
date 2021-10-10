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
  StorageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  StorageQueueDataMessageProcessor: '8a0f0c08-91a1-4084-bc3d-661d67233fed'
  StorageQueueDataMessageSender: 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  StorageQueueDataReader: '19e7f393-937e-4f77-808e-94535e297925'
}


resource azStorageAccountQueueExistingResource 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-04-01' existing = if(resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}


// 2. Assign Resource Role Scoped to the resource
resource azStorageAccountQueueResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azStorageAccountQueueExistingResource
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}


// 3. Assign Resource Role Scoped to the Resource Group
resource azStorageAccountQueueResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
