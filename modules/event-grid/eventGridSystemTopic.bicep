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

@description('')
param eventGridSystemTopicName string

@description('')
param eventGridSystemTopicLocation string = resourceGroup().location

@description('')
param eventGridSystemTopicMsiEnabled bool = false

@allowed([
  'Microsoft.Storage.StorageAccounts'
  'Microsoft.AgFoodPlatform.FarmBeats'
  'Microsoft.ApiManagement.Service'
  'Microsoft.AppConfiguration.ConfigurationStores'
  'Microsoft.Cache.Redis'
  'Microsoft.Communication.CommunicationServices'
  'Microsoft.ContainerRegistry.Registries'
  'Microsoft.Devices.IoTHubs'
  'Microsoft.EventGrid.Domains'
  'Microsoft.EventGrid.Topics'
  'Microsoft.Eventhub.Namespaces'
  'Microsoft.HealthcareApis.Workspaces'
  'Microsoft.KeyVault.vaults'
  'Microsoft.MachineLearningServices.Workspaces'
  'Microsoft.Maps.Accounts'
  'Microsoft.Media.MediaServices'
  'Microsoft.PolicyInsights.PolicyStates'
  'Microsoft.Resources.ResourceGroups'
  'Microsoft.Resources.Subscriptions'
  'Microsoft.ServiceBus.Namespaces'
  'Microsoft.SignalRService.SignalR'
  'Microsoft.Storage.StorageAccounts'
  'Microsoft.Web.ServerFarms'
  'Microsoft.Web.Sites'
])
@description('')
param eventGridSystemTopicSourceType string

@description('')
param eventGridSystemTopicSourceName string

@description('')
param eventGridSystemTopicSourceResourceGroup string

@description('A collectio nof subscriptions to deploy with the Event Grid Topic')
param eventGridSystemTopicSubscriptions array = []

@description('')
param eventGridSystemTopicMsiRoleAssignments array = []

@description('')
param eventGridSystemTopicTags object = {}

resource azEventGridSystemTopicDeployment 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: replace(replace(eventGridSystemTopicName, '@environment', environment), '@region', region)
  location: eventGridSystemTopicLocation
  identity: {
    type: eventGridSystemTopicMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    source: replace(replace(resourceId(eventGridSystemTopicSourceResourceGroup, 'Microsoft.Storage/storageAccounts', eventGridSystemTopicSourceName), '@environment', environment), '@region', region)
    topicType: eventGridSystemTopicSourceType
  }
  tags: union(eventGridSystemTopicTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

// 2. Deploy the Event Grid Domain Topic Subscriptions, if applicable
module azEventGridSystemTopicSubscriptionsDeployment 'eventGridSystemTopicSubscription.bicep' = [for (subscription, index) in eventGridSystemTopicSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridSystemTopicSubscriptions) ? toLower('az-egs-topic-sub-${guid('${azEventGridSystemTopicDeployment.id}/${subscription.eventGridSystemTopicSubscriptionName}')}') : 'no-egs-subscription-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridSystemTopicName: eventGridSystemTopicName
    eventGridSystemTopicSubscriptionName: subscription.eventGridSystemTopicSubscriptionName
    eventGridSystemTopicSubscriptionEndpointType: subscription.eventGridSystemTopicSubscriptionEndpointType
    eventGridSystemTopicSubscriptionEndpointName: subscription.eventGridSystemTopicSubscriptionEndpointName
    eventGridSystemTopicSubscriptionEndpointResourceGroup: subscription.eventGridSystemTopicSubscriptionEndpointResourceGroup
    eventGridSystemTopicSubscriptionEventSubjectFilters: contains(subscription, 'eventGridSystemTopicSubscriptionEventSubjectFilters') ?  subscription.eventGridSystemTopicSubscriptionEventSubjectFilters: {}
    eventGridSystemTopicSubscriptionEventTypes: contains(subscription, 'eventGridSystemTopicSubscriptionEventTypes') ? subscription.eventGridSystemTopicSubscriptionEventTypes : []
    eventGridSystemTopicSubscriptionEventFilters: contains(subscription, 'eventGridSystemTopicSubscriptionEventFilters') ? subscription.eventGridSystemTopicSubscriptionEventFilters : []
    eventGridSystemTopicSubscriptionEventLabels: contains(subscription, 'eventGridSystemTopicSubscriptionEventLabels') ? subscription.eventGridSystemTopicSubscriptionEventLabels : []
    eventGridSystemTopicSubscriptionDeadLetterDestination: contains(subscription, 'eventGridSystemTopicSubscriptionDeadLetterDestination') ? subscription.eventGridSystemTopicSubscriptionDeadLetterDestination : {}
    eventGridSystemTopicSubscriptionEventHeaders: contains(subscription, 'eventGridSystemTopicSubscriptionEventHeaders') ? subscription.eventGridSystemTopicSubscriptionEventHeaders : []
    eventGridSystemTopicSubscriptionMsiEnabled: contains(subscription, 'eventGridSystemTopicSubscriptionMsiEnabled') ? subscription.eventGridSystemTopicSubscriptionMsiEnabled : false
  }
  dependsOn: [
    azEventGridSystemTopicRoleAssignment
  ]
}]


// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal
module azEventGridSystemTopicRoleAssignment '../rbac/rbac.bicep' = [for roleAssignment in eventGridSystemTopicMsiRoleAssignments: if (eventGridSystemTopicMsiEnabled == true && !empty(eventGridSystemTopicMsiRoleAssignments)) {
  name: 'egst-rbac-${guid('${azEventGridSystemTopicDeployment.name}-${roleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(roleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: roleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: roleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: roleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: roleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: roleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: azEventGridSystemTopicDeployment.identity.principalId
  }
}]

output eventGridSystemTopic object = azEventGridSystemTopicDeployment
