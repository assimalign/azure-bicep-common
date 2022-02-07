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

// A collection of available roles to assign to service principals for Cognitive Services
var RoleDefinitionId = {
  CognitiveServicesCustomVisionContributor: 'c1ff6cc2-c111-46fe-8896-e0ef812ad9f3'
  CognitiveServicesCustomVisionDeployment: '5c4089e1-6d96-4d2f-b296-c1bc7137275f'
  CognitiveServicesCustomVisionLabeler: '88424f51-ebe7-446f-bc41-7fa16989e96c'
  CognitiveServicesCustomVisionReader: '93586559-c37d-4a6b-ba08-b9f0940c2d73'
  CognitiveServicesCustomVisionTrainer: '0a5ae4ab-0d65-4eeb-be61-29fc9b54394b'
  CognitiveServicesQnAMakerReader: '466ccd10-b268-4a11-b098-b4849f024126'
  CognitiveServicesQnAMakerEditor: 'f4cc2bf9-21be-47a1-bdf1-5c5804381025'
  CognitiveServicesMetricsAdvisorAdministrator: 'cb43c632-a144-4ec5-977c-e80c4affc34a'
  CognitiveServicesMetricsAdvisorUser: '3b20f47b-3825-43cb-8114-4bd2201156a8'
  CognitiveServicesSpeechUser: 'f2dc8367-1007-4938-bd23-fe263f013447'
  CognitiveServicesSpeechContributor: '0e75ca1e-0464-4b4d-8b93-68208a576181'
  CognitiveServicesFaceRecognizer: '9894cab4-e18a-44aa-828b-cb588cd6f2d7'
  CognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  CognitiveServicesDataReader: 'b59867f0-fa02-499b-be73-45a86b5b3e1c'
  CognitiveServicesContributor: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
}

// 1. If applicable, get existing cognitive services resource
resource azCognitiveServicesExistingResource 'Microsoft.CognitiveServices/accounts@2021-04-30' existing = if (resourceRoleAssignmentScope == 'Resource') {
  name: replace(replace(resourceToScopeRoleAssignment, '@environment', environment), '@location', location)
}

// 2. Assign Resource Role Scoped to the resource
resource azCognitiveServicesResourceScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'Resource') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: azCognitiveServicesExistingResource
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}

// 3. Assign Resource Role Scoped to the Resource Group
resource azCognitiveServicesResourceGroupScopedRoleAssignmentDeployment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if (resourceRoleAssignmentScope == 'ResourceGroup') {
  name: guid('${resourcePrincipalIdReceivingRole}/${RoleDefinitionId[resourceRoleName]}')
  scope: resourceGroup()
  properties: {
    principalId: resourcePrincipalIdReceivingRole
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId[resourceRoleName])
  }
}
