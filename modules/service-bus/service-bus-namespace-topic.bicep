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

@description('The name of the Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the Service Bus Topic to deploy')
param serviceBusTopicName string

@description('A list of Service Bus Topic Subscriptions to deploy for the topic')
param serviceBusTopicSubscriptions array = []

@description('A list of configurations for the Service Bus Topic')
param serviceBusTopicSettings object = {}

@description('A list of Service Bus Topic Policies to deploy with the Topic')
param serviceBusTopicPolicies array = []

// 1. Deploy Service Bus Namespace Topic
resource serviecBusNamespaceTopic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopicName}', '@environment', environment), '@region', region)
  properties: {
    maxSizeInMegabytes: contains(serviceBusTopicSettings, 'maxSize') ? serviceBusTopicSettings.maxSize : 1024
  }
}

// 2. Deploy Service Bus Namespace Topic Authorization Policy
module serviecBusNamespaceTopicAuthPolicy 'service-bus-namespace-topic-authorization.bicep' = [for policy in serviceBusTopicPolicies: if (!empty(policy)) {
  name: !empty(serviceBusTopicPolicies) ? toLower('sbn-topic-subs-${guid('${serviecBusNamespaceTopic.id}/${policy.serviceBusPolicyName}')}') : 'no-sbt-policies-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopicName: serviceBusTopicName
    serviceBusTopicPolicyName: policy.serviceBusPolicyName
    serviceBusTopicPolicyPermissions: policy.serviceBusPolicyPermissions
  }
}]

// 2. Deploye Service Bus Namespace Topic Subscriptions if applicable
module serviecBusNamespaceTopicSubscription 'service-bus-namespace-topic-subscription.bicep' = [for subscription in serviceBusTopicSubscriptions: if (!empty(subscription)) {
  name: !empty(serviceBusTopicSubscriptions) ? toLower('sbn-topic-subs-${guid('${serviecBusNamespaceTopic.id}/${subscription.serviceBusTopicSubscriptionName}')}') : 'no-subscription-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopicName: serviceBusTopicName
    serviceBusTopicSubscriptionName: subscription.serviceBusTopicSubscriptionName
    serviceBusTopicSubscriptionSettings: contains(subscription, 'serviceBusTopicSubscriptionSettings') ? subscription.serviceBusTopicSubscriptionSettings : {}
    serviceBusTopicSubscriptionCorrelationFilters: contains(subscription, 'serviceBusTopicSubscriptionCorrelationFilters') ? subscription.serviceBusTopicSubscriptionCorrelationFilters : []
  }
}]


output serviecBusNamespaceTopic object = serviecBusNamespaceTopic
