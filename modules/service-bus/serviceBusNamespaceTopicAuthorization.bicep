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

@description('The name of the Service Bus Topic to deploy')
param serviceBusTopicName string

@description('')
param serviceBusTopicPolicyName string

@description('')
param serviceBusTopicPolicyPermissions array

// 1.1 Add the authorization rules
resource azServiceBusQueueAuthorizationRulesDeployment 'Microsoft.ServiceBus/namespaces/topics/authorizationRules@2021-11-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopicName}/${serviceBusTopicPolicyName}', '@environment', environment), '@region', region)
  properties: {
    rights: serviceBusTopicPolicyPermissions
  }
}
