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

  StorageFileDataSMBShareReader: 'aba4ae5f-2193-4029-9191-0cb91df5e314'
  StorageFileDataSMBShareContributor: '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
  StorageFileDataSMBShareElevatedContributor: 'a7264617-510b-434b-a828-9731dc254ea7'
}



resource azStorageAccountFileShareExistingResource 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' existing = if(resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}


// 2. Assign Resource Role Scoped to the Resource
resource azStorageAccountFileSharerResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azStorageAccountFileShareExistingResource
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}


// 3. Assign Resource Role Scoped to the Resource Group
resource azStorageAccountFileShareResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdRecievingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdRecievingRole 
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
