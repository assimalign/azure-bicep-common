@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

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

// A collection of available roles to assign to service principals for Storage Account
var RoleDefinitionId = {
  StorageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  StorageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDelegator: 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'
  StorageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  StorageQueueDataMessageProcessor: '8a0f0c08-91a1-4084-bc3d-661d67233fed'
  StorageQueueDataMessageSender: 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  StorageQueueDataReader: '19e7f393-937e-4f77-808e-94535e297925'
  StorageTableDataReader: '76199698-9eea-4c19-bc75-cec21354c6b6'
  StorageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  StorageAccountContributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  StorageFileDataSMBShareReader: 'aba4ae5f-2193-4029-9191-0cb91df5e314'
  StorageFileDataSMBShareContributor: '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
  StorageFileDataSMBShareElevatedContributor: 'a7264617-510b-434b-a828-9731dc254ea7'
  StorageAccountBackupContributorRole: 'e5e2a7ff-d759-4cd2-bb51-3152d37e2eb1'
  StorageAccountKeyOperatorServiceRole: '81a9662b-bebf-436f-a333-f67b29880f12'
}

// 1. If applicable, get existing storage account resource to scope role assignment
resource azStorageAccountExistingResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@region', region)
}

// 2. Assign Resource Role Scoped to the resource
resource azStorageAccountResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azStorageAccountExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azStorageAccountResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
