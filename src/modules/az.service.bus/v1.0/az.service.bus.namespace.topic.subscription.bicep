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

@description('The name of the Service Bus for the Topic Subscription')
param serviceBusName string

@description('The name of the Service Bus Topic for the Subscription')
param serviceBusTopicName string

@description('The name of Subscription to deploy')
param serviceBusTopicSubscriptionName string

@description('')
param serviceBusTopicSubscriptionSettings object = {}

resource azServiceBusTopicSubscriptionsDeployment 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopicName}/${serviceBusTopicSubscriptionName}', '@environment', environment), '@region', region)
  properties: {
    requiresSession: contains(serviceBusTopicSubscriptionSettings, 'enableSession') ? serviceBusTopicSubscriptionSettings.enableSession : false
    maxDeliveryCount: contains(serviceBusTopicSubscriptionSettings, 'maxDelivery') ? serviceBusTopicSubscriptionSettings.maxDelivery : 15
  }
}
