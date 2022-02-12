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
param eventGridName string

@description('The pricing tier for the Event Grid Domain')
param eventGridSku object

@description('A list of object with the Topics and Subscriptions to be deployed under the Event Grid Resource')
param eventGridTopics array = []

@description('A list of subscriptions to deploy under the Event Grid')
param eventGridSubscriptions array = []

@description('Configurations for implementing a Private Endpoint for the Event Grid Domain')
param eventGridPrivateEndpoint object = {}

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridMsiEnabled bool = false

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridMsiRoleAssignments array = []

@description('Disables or Enables Public Network Access to the event grid domain')
param eventGridPublicAccess bool = false



// 1. Deploy Event Grid Domain
resource azEventGridDomainDeployment 'Microsoft.EventGrid/domains@2021-06-01-preview' = {
  name: replace(replace('${eventGridName}', '@environment', environment), '@region', region)
  location: resourceGroup().location
  identity: {
    type: eventGridMsiEnabled == true ? 'SystemAssigned'  : 'None'
  }
  sku: any(environment == 'dev' ? {
    name: eventGridSku.dev
  } : any(environment == 'qa' ? {
    name: eventGridSku.qa
  } : any(environment == 'uat' ? {
    name: eventGridSku.uat
  } : any(environment == 'prd' ? {
    name: eventGridSku.prd
  } : {
    name: 'Basic'
  }))))
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: eventGridPublicAccess == true ? 'Disabled' : 'Enabled'
  }
}

// 2. Deploy Event Grid Topic & Topic Subscriptions
module azEventGridTopicSubscriptionDeployment 'az.event.grid.domain.topic.bicep' = [for (topic, index) in eventGridTopics: if (!empty(topic)) {
  name: !empty(eventGridTopics) ? toLower('az-egd-topic-${guid('${azEventGridDomainDeployment.id}/${topic.name}')}')  : 'no-eg-topics-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridDomainName: eventGridName
    eventGridDomainTopicName: topic.name 
    eventGridDomainSubscriptions: topic.subscriptions
  }
}]

// 3. Deploy Event Grid Domain Subscriptions
module azEventGridSubscriptionDeployment 'az.event.grid.domain.subscription.bicep' = [for (subscription, index) in eventGridSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridSubscriptions) ? toLower('az-egd-subscription-${guid('${azEventGridDomainDeployment.id}/${subscription.name}')}')  : 'no-eg-subscriptions-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridDomainName: eventGridName
    eventGridSubscriptionName: subscription.name 
    eventGridSubscriptionEndpointName: subscription.endpointName 
    eventGridEventTypes: subscription.eventTypes 
    eventGridSubscriptionEndpointResourceGroup: subscription.endpointResourceGroup 
    eventGridSubscriptionEndpointType: subscription.endpointType 
    eventGridEventFilters: subscription.eventFilters 
    eventGridDeadLetterDestination: subscription.eventDeadLetterDestination
    eventGridEventLabels: subscription.eventLabels
    eventGridEventDeliveryHeaders: subscription.eventHeaders
    eventGridSubscriptionUseMsi: subscription.eventMsiEnabled
  }
}]

// 4. Deploy Private Endpoint if applicable
module azEventGridPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if(!empty(eventGridPrivateEndpoint)) {
  name: !empty(eventGridPrivateEndpoint) ? toLower('az-egd-priv-endpoint-${guid('${azEventGridDomainDeployment.id}/${eventGridPrivateEndpoint.name}')}') : 'no-egd-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: eventGridPrivateEndpoint.name
    privateEndpointPrivateDnsZone: eventGridPrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-eventgrid-azure-net'
    privateEndpointPrivateDnsZoneResourceGroup: eventGridPrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: eventGridPrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: eventGridPrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: eventGridPrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azEventGridDomainDeployment.id
    privateEndpointGroupIds: [
      'domain'
    ]
  }
}


// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module azEventGridRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for roleAssignment in eventGridMsiRoleAssignments: if (eventGridMsiEnabled == true && !empty(eventGridMsiRoleAssignments)) {
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
    azEventGridTopicSubscriptionDeployment
    azEventGridSubscriptionDeployment
  ]
}]
