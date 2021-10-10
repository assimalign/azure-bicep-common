@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the service bus queue to deploy with the service bus namespace')
param serviceBusQueueName string

@description('')
param serviceBusQueueSettings object = {}

@description('A list of authorization policies to deploy with the service bus queue')
param serviceBusQueuePolicies array = []


resource azServiceBusTopicsDeployment 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = {
  name: replace('${serviceBusName}/${serviceBusQueueName}', '@environment', environment)
  properties: any(!empty(serviceBusQueueSettings) ? {
    maxSizeInMegabytes: serviceBusQueueSettings.maxSize ?? 1024  
  } : {})
}


module azServiceBusTopicAuthPolicyDeployment  'az.intg.service.bus.queue.authorization.bicep' = [for policy in serviceBusQueuePolicies: if (!empty(policy)) {
  name: !empty(serviceBusQueuePolicies) ? toLower('az-sbn-queue-policy-${guid('${azServiceBusTopicsDeployment.id}/${policy.name}')}') : 'no-sbq-policy-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    serviceBusName : serviceBusName
    serviceBusQueueName: serviceBusQueueName
    serviceBusQueuePolicyName: policy.name
    serviceBusQueuePolicyPermissions: policy.permissions
  }
  dependsOn: [
    azServiceBusTopicsDeployment
  ]
}]
