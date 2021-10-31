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

@description('The name of an existing Event Grid Domain to deploy the new Topic to')
param eventGridDomainName string

@description('Then name of the new Event Grid Topic to deploy')
param eventGridDomainTopicName string

@description('A collectio nof subscriptions to deploy with the Event Grid Topic')
param eventGridDomainSubscriptions array = []



// 1. Deploy the Event Grid Domain Topic
resource azEventGridTopicDomainDeployment 'Microsoft.EventGrid/domains/topics@2020-10-15-preview' = {
  name: replace(replace('${eventGridDomainName}/${eventGridDomainTopicName}', '@environment', environment), '@location', location)
}

// 2. Deploy the Event Grid Domain Topic Subscriptions, if applicable
module azEventGridDomainTopicSubscriptionsDeployment 'az.intg.event.grid.domain.topic.subscription.bicep' = [for (subscription, index) in eventGridDomainSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridDomainSubscriptions) ? toLower('az-egd-subscriptions-${guid('${azEventGridTopicDomainDeployment.id}/${subscription.name}')}') : 'no-egd-subscription-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    eventGridDomainName: eventGridDomainName
    eventGridDomainTopicName: eventGridDomainTopicName
    eventGridEventTypes: subscription.eventTypes
    eventGridSubscriptionName: subscription.name
    eventGridSubscriptionEndpointName: subscription.endpointName
    eventGridSubscriptionEndpointResourceGroup: subscription.endpointResourceGroup
    eventGridSubscriptionEndpointType: subscription.endpointType
    eventGridEventFilters: subscription.eventFilters
    eventGridEventLabels: subscription.eventTypes
    eventGridDeadLetterDestination: subscription.eventDeadLetterDestination
    eventGridEventDeliveryHeaders: subscription.eventHeaders
    eventGridSubscriptionUseMsi: subscription.eventMsiEnabled
  }
  dependsOn: [
    azEventGridTopicDomainDeployment
  ]
}]

// 3. Return Deployment Output
output resource object = azEventGridTopicDomainDeployment
