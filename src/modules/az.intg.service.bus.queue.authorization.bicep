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

@description('')
param serviceBusQueueName string

@description('')
param serviceBusQueuePolicyName string

@description('')
param serviceBusQueuePolicyPermissions array



resource azServiceBusQueueAuthorizationRulesDeployment 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2017-04-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusQueueName}/${serviceBusQueuePolicyName}', '@environment', environment), '@location', location)
  properties: {
    rights: serviceBusQueuePolicyPermissions
  }
}
