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

@description('The name of the Azure Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the Azure Service Bus Queue.')
param serviceBusQueueName string

@description('The name of the Azure Service Bus Queue Policy Name.')
param serviceBusQueuePolicyName string

@description('The permissions to be set for the Azure Service Bus Queue Policy.')
param serviceBusQueuePolicyPermissions array

resource azServiceBusQueueAuthorizationRulesDeployment 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusQueueName}/${serviceBusQueuePolicyName}', '@environment', environment), '@region', region)
  properties: {
    rights: serviceBusQueuePolicyPermissions
  }
}
