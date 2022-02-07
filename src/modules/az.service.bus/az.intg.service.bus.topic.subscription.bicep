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

@description('The name of the Service Bus for the Topic Subscription')
param serviceBusName string

@description('The name of the Service Bus Topic for the Subscription')
param serviceBusTopic string

@description('The name of Subscription to deploy')
param serviceBusTopicSubscription string

@description('')
param serviceBusTopicSubscriptionSettings object = {}



resource azServiceBusTopicSubscriptionsDeployment 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopic}/${serviceBusTopicSubscription}', '@environment', environment), '@location', location)
  properties: {
    forwardTo: ''
   
  }
}
