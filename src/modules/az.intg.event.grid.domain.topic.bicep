@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('')
param eventGridDomainName string

@description('')
param eventGridDomainTopicName string

@description('')
param eventGridDomainSubscriptions array = []




resource azEventGridTopicDomainDeployment 'Microsoft.EventGrid/domains/topics@2020-10-15-preview' = {
  name: replace('${eventGridDomainName}/${eventGridDomainTopicName}', '@environment', environment)
}


module azEventGridDomainTopicSubscriptionsDeployment 'az.intg.event.grid.domain.topic.subscription.bicep' = [for (subscription, index) in eventGridDomainSubscriptions: if (!empty(subscription)) {
  name: !empty(eventGridDomainSubscriptions) ? toLower('az-egd-subscriptions-${guid('${azEventGridTopicDomainDeployment.id}/${subscription.name}')}') : 'no-egd-subscription-to-deploy'
  scope: resourceGroup()
  params: {
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
  }
}]
