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

@description('The name of the service bus to deploy')
param serviceBusName string

@description('The location/region the Azure Service Bus Instance will be deployed to.')
param serviceBusLocation string = resourceGroup().location

@description('A collection of service bus topics to be deployed with the namespace.')
param serviceBusTopics array = []

@description('A collection of service bus queues to be deployed with the namespace.')
param serviceBusQueues array = []

@description('The pricing tier to be used for the service bus.')
param serviceBusSku object

@description('')
param serviceBusEnableMsi bool = false

@description('')
param serviceBusPolicies array = []

// 1. Deploy Service Bus Namespace
resource azServiceBusNamespaceDeployment 'Microsoft.ServiceBus/namespaces@2018-01-01-preview' = {
  name: replace(replace('${serviceBusName}', '@environment', environment), '@region', region)
  location: serviceBusLocation
  identity: any(serviceBusEnableMsi ? {
    type: 'SystemAssigned'
  } : json('null'))
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
  resource azServiceBusNamespaceAuthorizationRulesDeployment 'AuthorizationRules@2021-11-01' = [for policy in serviceBusPolicies: if (!empty(policy)) {
    name: !empty(serviceBusPolicies) ? policy.name : 'no-sb-policies-to-deploy'
    properties: {
      rights: policy.permissions
    }
  }]
}

// 2. Deploy Servic Bus Queues if applicable
module azServiceBusNamespaceQueuesDeployment 'az.service.bus.namespace.queue.bicep' = [for queue in serviceBusQueues: if (!empty(queue)) {
  name: !empty(serviceBusQueues) ? toLower('az-sbn-queue-${guid('${azServiceBusNamespaceDeployment.id}/${queue.name}')}') : 'no-sb-queues-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    serviceBusName: serviceBusName
    serviceBusQueueName: queue.serviceBusQueueName
    serviceBusQueuePolicies: contains(queue, 'serviceBusQueuePolicies') ? queue.serviceBusQueuePolicies : []
    serviceBusQueueSettings: contains(queue, 'serviceBusQueueSettings') ? queue.serviceBusQueueSettings : {}
  }
}]

// 3. Deploy Servic Bus Topics & Subscriptions if applicable
module azServiceBusTopicsNamespaceDeployment 'az.service.bus.namespace.topic.bicep' = [for topic in serviceBusTopics: if (!empty(topic)) {
  name: !empty(serviceBusTopics) ? toLower('az-sbn-topic-${guid('${azServiceBusNamespaceDeployment.id}/${topic.name}')}') : 'no-sb-topic-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    serviceBusName: serviceBusName
    serviceBusTopicName: topic.serviceBusTopicName
    serviceBusTopicSubscriptions: contains(topic, 'serviceBusTopicSubscriptions') ? topic.serviceBusTopicSubscriptions : []
    serviceBusTopicPolicies: contains(topic, 'serviceBusTopicPolicies') ? topic.serviceBusTopicPolicies : []
    serviceBusTopicSettings: contains(topic, 'serviceBusTopicSettings') ? topic.serviceBusTopicSettings : {}
  }
}]
