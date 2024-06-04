@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource egsTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: formatName(eventGridSystemTopicName, affix, environment, region)
  location: eventGridSystemTopicLocation
  identity: {
    type: eventGridSystemTopicMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    source: resourceId(
      formatName(eventGridSystemTopicSourceResourceGroup, affix, environment, region),
      'Microsoft.Storage/storageAccounts',
      formatName(eventGridSystemTopicSourceName, affix, environment, region)
    )
    topicType: eventGridSystemTopicSourceType
  }
  tags: union(eventGridSystemTopicTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 2. Deploy the Event Grid Domain Topic Subscriptions, if applicable
module egsTopicSubscriptions 'event-grid-system-topic-subscription.bicep' = [
  for (subscription, index) in eventGridSystemTopicSubscriptions: if (!empty(subscription)) {
    name: !empty(eventGridSystemTopicSubscriptions)
      ? toLower('az-egs-topic-sub-${guid('${egsTopic.id}/${subscription.eventGridSystemTopicSubscriptionName}')}')
      : 'no-egs-subscription-to-deploy'
    scope: resourceGroup()
    params: {
      affix: affix
      region: region
      environment: environment
      eventGridSystemTopicName: eventGridSystemTopicName
      eventGridSystemTopicSubscriptionName: subscription.eventGridSystemTopicSubscriptionName
      eventGridSystemTopicSubscriptionEndpointType: subscription.eventGridSystemTopicSubscriptionEndpointType
      eventGridSystemTopicSubscriptionEndpointName: subscription.eventGridSystemTopicSubscriptionEndpointName
      eventGridSystemTopicSubscriptionEndpointResourceGroup: subscription.eventGridSystemTopicSubscriptionEndpointResourceGroup
      eventGridSystemTopicSubscriptionEventSubjectFilters: subscription.?eventGridSystemTopicSubscriptionEventSubjectFilters
      eventGridSystemTopicSubscriptionEventTypes: subscription.?eventGridSystemTopicSubscriptionEventTypes
      eventGridSystemTopicSubscriptionEventFilters: subscription.?eventGridSystemTopicSubscriptionEventFilters
      eventGridSystemTopicSubscriptionEventLabels: subscription.?eventGridSystemTopicSubscriptionEventLabels
      eventGridSystemTopicSubscriptionDeadLetterDestination: subscription.?eventGridSystemTopicSubscriptionDeadLetterDestination
      eventGridSystemTopicSubscriptionEventHeaders: subscription.?eventGridSystemTopicSubscriptionEventHeaders
      eventGridSystemTopicSubscriptionMsiEnabled: subscription.?eventGridSystemTopicSubscriptionMsiEnabled
    }
    dependsOn: [
      egsTopicRoleAssignment
    ]
  }
]

// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal
module egsTopicRoleAssignment '../rbac/rbac.bicep' = [
  for roleAssignment in eventGridSystemTopicMsiRoleAssignments: if (eventGridSystemTopicMsiEnabled == true && !empty(eventGridSystemTopicMsiRoleAssignments)) {
    name: 'egst-rbac-${guid('${egsTopic.name}-${roleAssignment.resourceRoleName}')}'
    scope: resourceGroup(formatName(roleAssignment.resourceGroupToScopeRoleAssignment, affix, environment, region))
    params: {
      affix: affix
      region: region
      environment: environment
      resourceRoleName: roleAssignment.resourceRoleName
      resourceToScopeRoleAssignment: roleAssignment.resourceToScopeRoleAssignment
      resourceGroupToScopeRoleAssignment: roleAssignment.resourceGroupToScopeRoleAssignment
      resourceRoleAssignmentScope: roleAssignment.resourceRoleAssignmentScope
      resourceTypeAssigningRole: roleAssignment.resourceTypeAssigningRole
      resourcePrincipalIdReceivingRole: egsTopic.identity.principalId
    }
  }
]

output eventGridSystemTopic object = egsTopic
