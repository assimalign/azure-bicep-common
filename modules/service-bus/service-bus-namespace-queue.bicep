@allowed([
  ''
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

@description('The name of the service bus queue to deploy with the service bus namespace')
param serviceBusQueueName string

@description('The settings for the instance of the Service Bus Queue.')
param serviceBusQueueSettings object = {}

@description('A list of authorization policies to deploy with the service bus queue')
param serviceBusQueuePolicies array = []

resource serviceBusNamespaceQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusQueueName}', '@environment', environment), '@region', region)
  properties: {
    requiresSession: contains(serviceBusQueueSettings, 'enableSession') ? serviceBusQueueSettings.enableSession : false
    maxSizeInMegabytes: contains(serviceBusQueueSettings, 'maxSize') ? serviceBusQueueSettings.maxSize : 1024
  }
}

module serviceBusNamespaceQueueAuthPolicy 'service-bus-namespace-queue-authorization.bicep' = [for policy in serviceBusQueuePolicies: if (!empty(policy)) {
  name: !empty(serviceBusQueuePolicies) ? toLower('sbn-queue-policy-${guid('${serviceBusNamespaceQueue.id}/${policy.serviceBusPolicyName}')}') : 'no-sbq-policy-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    serviceBusName: serviceBusName
    serviceBusQueueName: serviceBusQueueName
    serviceBusQueuePolicyName: policy.serviceBusPolicyName
    serviceBusQueuePolicyPermissions: policy.serviceBusPolicyPermissions
  }
}]

output serviceNamespaceQueue object = serviceBusNamespaceQueue
