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

@description('The name of the Event Grid Domain to deploy')
param eventGridDomainName string

@description('The location/region the Azure Event Grid Domain will be deployed to.')
param eventGridDomainLocation string = resourceGroup().location

@description('A list of object with the Topics and Subscriptions to be deployed under the Event Grid Resource')
param eventGridDomainTopics array = []

@description('A list of subscriptions to deploy under the Event Grid')
param eventGridDomainSubscriptions array = []

@description('Configurations for implementing a Private Endpoint for the Event Grid Domain')
param eventGridDomainPrivateEndpoint object = {}

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridDomainMsiEnabled bool = false

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridDomainMsiRoleAssignments array = []

@description('Disables or Enables Public Network Access to the event grid domain')
param eventGridDomainDisablePublicAccess bool = false

// 1. Deploy Event Grid Domain
resource azEventGridDomainDeployment 'Microsoft.EventGrid/domains@2021-12-01' = {
  name: replace(replace('${eventGridDomainName}', '@environment', environment), '@region', region)
  location: eventGridDomainLocation
  identity: {
    type: eventGridDomainMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: eventGridDomainDisablePublicAccess == true ? 'Disabled' : 'Enabled'
  }
}

// 2. Deploy Event Grid Topic & Topic Subscriptions
module azEventGridDomainTopicsDeployment 'az.event.grid.domain.topic.bicep' = [for (topic, index) in eventGridDomainTopics: if (!empty(topic)) {
  name: !empty(eventGridDomainTopics) ? toLower('az-egd-topic-${guid('${azEventGridDomainDeployment.id}/${topic.eventGridDomainTopicName}')}') : 'no-egd-topics-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridDomainName: eventGridDomainName
    eventGridDomainTopicName: topic.eventGridDomainTopicName
    eventGridDomainTopicSubscriptions: contains(topic, 'eventGridDomainTopicSubscriptions') ? topic.eventGridDomainTopicSubscriptions : []
  }
}]

// 3. Deploy Event Grid Domain Subscriptions
module azEventGridDomainSubscriptionsDeployment 'az.event.grid.domain.subscription.bicep' = [for (subscription, index) in eventGridDomainSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridDomainSubscriptions) ? toLower('az-egd-subs-${guid('${azEventGridDomainDeployment.id}/${subscription.eventGridDomainSubscriptionName}')}') : 'no-eg-subs-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridDomainName: eventGridDomainName
    eventGridDomainSubscriptionName: subscription.eventGridDomainSubscriptionName
    eventGridDomainSubscriptionEndpointType: subscription.eventGridDomainSubscriptionEndpointType
    eventGridDomainSubscriptionEndpointName: subscription.eventGridDomainSubscriptionEndpointName
    eventGridDomainSubscriptionEndpointResourceGroup: subscription.eventGridDomainSubscriptionEndpointResourceGroup
    eventGridDomainSubscriptionEventTypes: contains(subscription, 'eventGridDomainSubscriptionEventTypes') ? subscription.eventGridDomainSubscriptionEventTypes : []
    eventGridDomainSubscriptionEventFilters: contains(subscription, 'eventGridDomainSubscriptionEventFilters') ? subscription.eventGridDomainSubscriptionEventFilters : []
    eventGridDomainSubscriptionEventLabels: contains(subscription, 'eventGridDomainSubscriptionEventLabels') ? subscription.eventGridDomainSubscriptionEventLabels : []
    eventGridDomainSubscriptionDeadLetterDestination: contains(subscription, 'eventGridDomainSubscriptionDeadLetterDestination') ? subscription.eventGridDomainSubscriptionDeadLetterDestination : {}
    eventGridDomainSubscriptionEventHeaders: contains(subscription, 'eventGridDomainSubscriptionEventHeaders') ? subscription.eventGridDomainSubscriptionEventHeaders : []
    eventGridDomainSubscriptionMsiEnabled: contains(subscription, 'eventGridDomainSubscriptionMsiEnabled') ? subscription.eventGridDomainSubscriptionMsiEnabled : false
  }
}]

// 4. Deploy Private Endpoint if applicable
module azEventGridPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(eventGridDomainPrivateEndpoint)) {
  name: !empty(eventGridDomainPrivateEndpoint) ? toLower('az-egd-priv-endpoint-${guid('${azEventGridDomainDeployment.id}/${eventGridDomainPrivateEndpoint.name}')}') : 'no-egd-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointLocation: contains(eventGridDomainPrivateEndpoint, 'privateEndpointLocation') ? eventGridDomainPrivateEndpoint.privateEndpointLocation : eventGridDomainLocation
    privateEndpointName: eventGridDomainPrivateEndpoint.privateEndpointName
    privateEndpointDnsZoneGroupName: 'privatelink-eventgrid-azure-net'
    privateEndpointDnsZoneName: eventGridDomainPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneResourceGroup: eventGridDomainPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azEventGridDomainDeployment.id
    privateEndpointGroupIds: [
      'domain'
    ]
  }
}

// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azEventGridRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for roleAssignment in eventGridDomainMsiRoleAssignments: if (eventGridDomainMsiEnabled == true && !empty(eventGridDomainMsiRoleAssignments)) {
  name: 'az-egd-rbac-${guid('${azEventGridDomainDeployment.name}-${roleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(roleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: roleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: roleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: roleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: roleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: roleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: azEventGridDomainDeployment.identity.principalId
  }
  dependsOn: [
    azEventGridDomainTopicsDeployment
    azEventGridDomainSubscriptionsDeployment
  ]
}]
