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

@description('The name of the Service Bus Topic to deploy')
param serviceBusTopicName string

@description('')
param serviceBusTopicPolicyName string

@description('')
param serviceBusTopicPolicyPermissions array 




// 1.1 Add the authorization rules
resource azServiceBusQueueAuthorizationRulesDeployment 'Microsoft.ServiceBus/namespaces/topics/authorizationRules@2017-04-01' = {
  name: replace(replace('${serviceBusName}/${serviceBusTopicName}/${serviceBusTopicPolicyName}', '@environment', environment), '@location', location)
  properties: {
    rights: serviceBusTopicPolicyPermissions
  }
}
