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

@description('The name of an existing Event Grid Domain to deploy the new Topic to')
param eventGridDomainName string

@description('Then name of the new Event Grid Topic to deploy')
param eventGridDomainTopicName string

@description('A collectio nof subscriptions to deploy with the Event Grid Topic')
param eventGridDomainTopicSubscriptions array = []

// 1. Deploy the Event Grid Domain Topic
resource azEventGridTopicDomainDeployment 'Microsoft.EventGrid/domains/topics@2020-10-15-preview' = {
  name: replace(replace('${eventGridDomainName}/${eventGridDomainTopicName}', '@environment', environment), '@region', region)
}

// 2. Deploy the Event Grid Domain Topic Subscriptions, if applicable
module azEventGridDomainTopicSubscriptionsDeployment 'az.event.grid.domain.topic.subscription.bicep' = [for (subscription, index) in eventGridDomainTopicSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridDomainTopicSubscriptions) ? toLower('az-egd-topic-sub-${guid('${azEventGridTopicDomainDeployment.id}/${subscription.eventGridDomainTopicSubscriptionName}')}') : 'no-egd-subscription-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    eventGridDomainName: eventGridDomainName
    eventGridDomainTopicName: eventGridDomainTopicName
    eventGridDomainTopicSubscriptionName: subscription.eventGridDomainTopicSubscriptionName
    eventGridDomainTopicSubscriptionEndpointType: subscription.eventGridDomainTopicSubscriptionEndpointType
    eventGridDomainTopicSubscriptionEndpointName: subscription.eventGridDomainTopicSubscriptionEndpointName
    eventGridDomainTopicSubscriptionEndpointResourceGroup: subscription.eventGridDomainTopicSubscriptionEndpointResourceGroup
    eventGridDomainTopicSubscriptionEventTypes: contains(subscription, 'eventGridDomainTopicSubscriptionEventTypes') ? subscription.eventGridDomainTopicSubscriptionEventTypes : []
    eventGridDomainTopicSubscriptionEventFilters: contains(subscription, 'eventGridDomainTopicSubscriptionEventFilters') ? subscription.eventGridDomainTopicSubscriptionEventFilters : []
    eventGridDomainTopicSubscriptionEventLabels: contains(subscription, 'eventGridDomainTopicSubscriptionEventLabels') ? subscription.eventGridDomainTopicSubscriptionEventLabels : []
    eventGridDomainTopicSubscriptionDeadLetterDestination: contains(subscription, 'eventGridDomainTopicSubscriptionDeadLetterDestination') ? subscription.eventGridDomainTopicSubscriptionDeadLetterDestination : {}
    eventGridDomainTopicSubscriptionEventHeaders: contains(subscription, 'eventGridDomainTopicSubscriptionEventHeaders') ? subscription.eventGridDomainTopicSubscriptionEventHeaders : []
    eventGridDomainTopicSubscriptionMsiEnabled: contains(subscription, 'eventGridDomainTopicSubscriptionMsiEnabled') ? subscription.eventGridDomainTopicSubscriptionMsiEnabled : false
  }
}]

// 3. Return Deployment Output
output eventGridDomainTopic object = azEventGridTopicDomainDeployment
