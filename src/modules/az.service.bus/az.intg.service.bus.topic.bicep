@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The location prefix or suffix for the resource name')
param location string = ''

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
resource azServiceBusTopicDeployment 'Microsoft.ServiceBus/namespaces/topics@2017-04-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopicName}', '@environment', environment), '@location', location)
  properties: any(!empty(serviceBusTopicSettings) ? {
    
    maxSizeInMegabytes: serviceBusTopicSettings.maxSize ?? 1024
  } : {})
}

// 2. Deploy Service Bus Namespace Topic Authorization Policy
module azServiceBusTopicPolicyDeployment 'az.intg.service.bus.topic.authorization.bicep' = [for policy in serviceBusTopicPolicies: if (!empty(policy)) {
  name: !empty(serviceBusTopicPolicies) ? toLower('az-sbn-topic-subs-${guid('${azServiceBusTopicDeployment.id}/${policy.name}')}') : 'no-sbt-policies-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopicName: serviceBusTopicName
    serviceBusTopicPolicyName: policy.name
    serviceBusTopicPolicyPermissions: policy.permissions
  }
}]

// 2. Deploye Service Bus Namespace Topic Subscriptions if applicable
module azServiceBusTopicSubscriptionDeployment 'az.intg.service.bus.topic.subscription.bicep' = [for subscription in serviceBusTopicSubscriptions: if (!empty(subscription)) {
  name: !empty(serviceBusTopicSubscriptions) ? toLower('az-sbn-topic-subs-${guid('${azServiceBusTopicDeployment.id}/${subscription.name}')}') : 'no-subscription-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopic: serviceBusTopicName
    serviceBusTopicSubscription: subscription.serviceBusTopicSubscriptionName
    serviceBusTopicSubscriptionSettings: contains(subscription, 'serviceBusTopicSubscriptionSettings') ? subscription.serviceBusTopicSubscriptionSettings : {}
  }
}]
