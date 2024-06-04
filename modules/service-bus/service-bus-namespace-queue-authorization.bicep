@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the Azure Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the Azure Service Bus Queue.')
param serviceBusQueueName string

@description('The name of the Azure Service Bus Queue Policy Name.')
param serviceBusQueuePolicyName string

@description('The permissions to be set for the Azure Service Bus Queue Policy.')
param serviceBusQueuePolicyPermissions array

resource serviceBusQueueAuthorizationRules 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2021-11-01' = {
  name: replace(replace(replace('${serviceBusName}/${serviceBusQueueName}/${serviceBusQueuePolicyName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    rights: serviceBusQueuePolicyPermissions
  }
}
