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

@description('The name of an existing Event Grid Domain to deploy the new Topic to')
param eventGridDomainName string

@description('Then name of the new Event Grid Topic to deploy')
param eventGridDomainTopicName string

@description('A collectio nof subscriptions to deploy with the Event Grid Topic')
param eventGridDomainTopicSubscriptions array = []

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy the Event Grid Domain Topic
resource azEventGridTopicDomainDeployment 'Microsoft.EventGrid/domains/topics@2022-06-15' = {
  name: formatName('${eventGridDomainName}/${eventGridDomainTopicName}', affix, environment, region)
}

// 2. Deploy the Event Grid Domain Topic Subscriptions, if applicable
module azEventGridDomainTopicSubscriptionsDeployment 'event-grid-domain-topic-subscription.bicep' = [
  for (subscription, index) in eventGridDomainTopicSubscriptions: if (!empty(subscription)) {
    name: !empty(eventGridDomainTopicSubscriptions)
      ? toLower('egd-topic-sub-${guid('${azEventGridTopicDomainDeployment.id}/${subscription.eventGridDomainTopicSubscriptionName}')}')
      : 'no-egd-subscription-to-deploy'
    scope: resourceGroup()
    params: {
      affix: affix
      region: region
      environment: environment
      eventGridDomainName: eventGridDomainName
      eventGridDomainTopicName: eventGridDomainTopicName
      eventGridDomainTopicSubscriptionName: subscription.eventGridDomainTopicSubscriptionName
      eventGridDomainTopicSubscriptionEndpointType: subscription.eventGridDomainTopicSubscriptionEndpointType
      eventGridDomainTopicSubscriptionEndpointName: subscription.eventGridDomainTopicSubscriptionEndpointName
      eventGridDomainTopicSubscriptionEndpointResourceGroup: subscription.eventGridDomainTopicSubscriptionEndpointResourceGroup
      eventGridDomainTopicSubscriptionEventSubjectFilters: subscription.?eventGridDomainTopicSubscriptionEventSubjectFiltersF
      eventGridDomainTopicSubscriptionEventTypes: subscription.?eventGridDomainTopicSubscriptionEventTypesF
      eventGridDomainTopicSubscriptionEventFilters: subscription.?eventGridDomainTopicSubscriptionEventFiltersF
      eventGridDomainTopicSubscriptionEventLabels: subscription.?eventGridDomainTopicSubscriptionEventLabelsF
      eventGridDomainTopicSubscriptionDeadLetterDestination: subscription.?eventGridDomainTopicSubscriptionDeadLetterDestinationF
      eventGridDomainTopicSubscriptionEventHeaders: subscription.?eventGridDomainTopicSubscriptionEventHeadersF
      eventGridDomainTopicSubscriptionMsiEnabled: subscription.?eventGridDomainTopicSubscriptionMsiEnabledF
    }
  }
]

// 3. Return Deployment Output
output eventGridDomainTopic object = azEventGridTopicDomainDeployment
