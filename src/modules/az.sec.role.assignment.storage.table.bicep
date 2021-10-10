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
  StorageTableDataReader: '76199698-9eea-4c19-bc75-cec21354c6b6'
  StorageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
}



resource azStorageAccountTableExistingResource 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-04-01' existing = if(resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}


// 2. Assign Resource Role Scoped to the resource
resource azStorageAccountTableResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azStorageAccountTableExistingResource
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}


// 3. Assign Resource Role Scoped to the Resource Group
resource azStorageAccountTableResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
