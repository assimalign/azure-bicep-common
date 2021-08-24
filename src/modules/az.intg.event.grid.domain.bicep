@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

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
param eventGridEnableMsi bool = false

@description('Disables or Enables Public Network Access to the event grid domain')
param eventGridPublicAccess bool = false




// 1. Deploy Event Grid Domain
resource azEventGridDomainDeployment 'Microsoft.EventGrid/domains@2020-10-15-preview' = {
  name: replace('${eventGridName}', '@environment', environment)
  location: resourceGroup().location
  identity: {
    type: eventGridEnableMsi == true ? 'SystemAssigned'  : 'None'
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
module azEventGridTopicSubscriptionDeployment 'az.intg.event.grid.domain.topic.bicep' = [for (topic, index) in eventGridTopics: if (!empty(topic)) {
  name: !empty(eventGridTopics) ? toLower('az-egd-topic-${guid('${azEventGridDomainDeployment.id}/${topic.name}')}')  : 'no-eg-topics-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    eventGridDomainName: eventGridName
    eventGridDomainTopicName: topic.name 
    eventGridDomainSubscriptions: topic.subscriptions
  }
  dependsOn: [
    azEventGridDomainDeployment
  ]
}]

// 3. Deploy Event Grid Domain Subscriptions
module azEventGridSubscriptionDeployment 'az.intg.event.grid.domain.subscription.bicep' = [for (subscription, index) in eventGridSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridSubscriptions) ? toLower('az-egd-subscription-${guid('${azEventGridDomainDeployment.id}/${subscription.name}')}')  : 'no-eg-subscriptions-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    eventGridDomainName: eventGridName
    eventGridSubscriptionName: subscription.name 
    eventGridSubscriptionEndpointName: subscription.endpointName 
    eventGridEventTypes: subscription.eventTypes 
    eventGridSubscriptionEndpointResourceGroup: subscription.endpointResourceGroup 
    eventGridSubscriptionEndpointType: subscription.endpointType 
    eventGridEventFilters: subscription.eventFilters 
  }
  dependsOn: [
    azEventGridDomainDeployment
  ]
}]

// 4. Deploy Private Endpoint if applicable
module azEventGridPrivateEndpointDeployment 'az.net.private.endpoint.bicep' = if(!empty(eventGridPrivateEndpoint)) {
  name: !empty(eventGridPrivateEndpoint) ? toLower('az-egd-private-endpoint-${guid('${azEventGridDomainDeployment.id}/${eventGridPrivateEndpoint.name}')}') : 'no-eg-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
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
  dependsOn: [
    azEventGridDomainDeployment
  ]
}
