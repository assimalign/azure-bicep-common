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

@description('The name of the Service Bus to deploy the Topic to')
param serviceBusName string

@description('The name of the Service Bus Topic to deploy')
param serviceBusTopicName string

@description('')
param serviceBusTopicPolicyName string

@description('')
param serviceBusTopicPolicyPermissions array

// 1.1 Add the authorization rules
resource serviceBusTopicAuthorizationRules 'Microsoft.ServiceBus/namespaces/topics/authorizationRules@2021-11-01' = {
  name: replace(replace(replace('${serviceBusName}/${serviceBusTopicName}/${serviceBusTopicPolicyName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    rights: serviceBusTopicPolicyPermissions
  }
}
