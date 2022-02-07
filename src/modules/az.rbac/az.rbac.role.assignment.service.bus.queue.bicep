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

// A collection of available roles to assign to service principals for Service Bus Namespace Queue
var RoleDefinitionId = {
  AzureServiceBusDataReceiver: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  AzureServiceBusDataSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  AzureServiceBusDataOwner: '090c5cfd-751d-490a-894a-3ce6f1109419'
}

// 1. If applicable, get existing service bus queue to scope role assignment
resource azServiceBusQueueExistingResource 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}

// 2. Assign Resource Role Scoped to the resource
resource azServiceBusQueueResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azServiceBusQueueExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azServiceBusQueueResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
