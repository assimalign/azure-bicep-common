@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The location prefix for the resource name')
param location string = ''

@description('The name of the service bus to deploy')
param serviceBusName string

@description('')
param serviceBusTopics array = []

@description('')
param serviceBusQueues array = []

@description('')
param serviceBusSku object

@description('')
param serviceBusEnableMsi bool = false

@description('')
param serviceBusPolicies array = []

// 1. Deploy Service Bus Namespace
resource azServiceBusNamespaceDeployment 'Microsoft.ServiceBus/namespaces@2018-01-01-preview' = {
  name: replace(replace('${serviceBusName}', '@environment', environment), '@location', location)
  location: resourceGroup().location
  identity: any(serviceBusEnableMsi ? {
    type: 'SystemAssigned'
  } : {})
  sku: any(environment == 'dev' ? {
    name: serviceBusSku.dev
    tier: serviceBusSku.dev
  } : any(environment == 'qa' ? {
    name: serviceBusSku.qa
    tier: serviceBusSku.qa
  } : any(environment == 'uat' ? {
    name: serviceBusSku.uat
    tier: serviceBusSku.uat
  } : any(environment == 'prd' ? {
    name: serviceBusSku.prd
    tier: serviceBusSku.prd
  } : {
    name: 'Basic'
    tier: 'Basic'
  }))))

  // Neet to use a different API version version than parent since preview supports managed identity while auth rules are supported up to 2017-04-01
  resource azServiceBusNamespaceAuthorizationRulesDeployment 'AuthorizationRules@2017-04-01' = [for policy in serviceBusPolicies: if (!empty(policy)) {
    name: !empty(serviceBusPolicies) ? policy.name : 'no-sb-policies-to-deploy'
    properties: {
      rights: policy.permissions
    }
  }]
}

// 2. Deploy Servic Bus Queues if applicable
module azServiceBusNamespaceQueuesDeployment 'az.intg.service.bus.queue.bicep' = [for queue in serviceBusQueues: if (!empty(queue)) {
  name: !empty(serviceBusQueues) ? toLower('az-sbn-queue-${guid('${azServiceBusNamespaceDeployment.id}/${queue.name}')}') : 'no-sb-queues-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    serviceBusName: serviceBusName
    serviceBusQueueName: queue.name
    serviceBusQueuePolicies: queue.policies
    serviceBusQueueSettings: queue.settings
  }
  dependsOn: [
    azServiceBusNamespaceDeployment
  ]
}]

// 3. Deploy Servic Bus Topics & Subscriptions if applicable
module azServiceBusTopicsNamespaceDeployment 'az.intg.service.bus.topic.bicep' = [for topic in serviceBusTopics: if (!empty(topic)) {
  name: !empty(serviceBusTopics) ? toLower('az-sbn-topic-${guid('${azServiceBusNamespaceDeployment.id}/${topic.name}')}') : 'no-sb-topic-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopicName: topic.name
    serviceBusTopicSubscriptions: topic.subscriptions
    serviceBusTopicPolicies: topic.policies
    serviceBusTopicSettings: topic.settings
  }
  dependsOn: [
    azServiceBusNamespaceDeployment
  ]
}]
