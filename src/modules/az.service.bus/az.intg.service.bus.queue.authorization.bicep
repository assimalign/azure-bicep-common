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

@description('The name of the Azure Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the Azure Service Bus Queue.')
param serviceBusQueueName string

@description('The name of the Azure Service Bus Queue Policy Name.')
param serviceBusQueuePolicyName string

@description('The permissions to be set for the Azure Service Bus Queue Policy.')
param serviceBusQueuePolicyPermissions array

resource azServiceBusQueueAuthorizationRulesDeployment 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2017-04-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusQueueName}/${serviceBusQueuePolicyName}', '@environment', environment), '@location', location)
  properties: {
    rights: serviceBusQueuePolicyPermissions
  }
}
