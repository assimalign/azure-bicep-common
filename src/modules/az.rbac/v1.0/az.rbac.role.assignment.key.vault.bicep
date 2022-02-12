@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

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

// A collection of available roles to assign to service principals for Key Vault
var RoleDefinitionId = {
  KeyVaultContributor: 'f25e0fa2-a7c8-4377-a976-54943a77a395'
  KeyVaultAdministrator: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  KeyVaultCryptoOfficer: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  KeyVaultCryptoUser: '12338af0-0e69-4776-bea7-57ae8d297424'
  KeyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  KeyVaultCertificatesOfficer: 'a4417e6f-fecd-4de8-b567-7b0420556985'
  KeyVaultReader: '21090545-7ca7-4776-b22c-e363652d74d2'
  KeyVaultCryptoServiceEncryptionUser: 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
}

// 1. Get an existing resource to scope the resource role assignment to, if applicable
resource azKeyVaultExistingResource 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@region', region)
}

// 2. Assign Resource Role Scoped to the resource
resource azKeyVaultResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azKeyVaultExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azKeyVaultResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
