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

@description('The name of the service bus queue to deploy with the service bus namespace')
param serviceBusQueueName string

@description('The settings for the instance of the Service Bus Queue.')
param serviceBusQueueSettings object = {}

@description('A list of authorization policies to deploy with the service bus queue')
param serviceBusQueuePolicies array = []

resource azServiceBusTopicsDeployment 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusQueueName}', '@environment', environment), '@location', location)
  properties: any(!empty(serviceBusQueueSettings) ? {
    maxSizeInMegabytes: serviceBusQueueSettings.maxSize ?? 1024
  } : {})
}

module azServiceBusTopicAuthPolicyDeployment 'az.intg.service.bus.queue.authorization.bicep' = [for policy in serviceBusQueuePolicies: if (!empty(policy)) {
  name: !empty(serviceBusQueuePolicies) ? toLower('az-sbn-queue-policy-${guid('${azServiceBusTopicsDeployment.id}/${policy.name}')}') : 'no-sbq-policy-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    serviceBusName: serviceBusName
    serviceBusQueueName: serviceBusQueueName
    serviceBusQueuePolicyName: policy.name
    serviceBusQueuePolicyPermissions: policy.permissions
  }
}]
