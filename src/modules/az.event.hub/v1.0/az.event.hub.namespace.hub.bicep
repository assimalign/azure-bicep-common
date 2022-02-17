@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Event Hub Namespace')
param eventHubNamespaceName string

@description('The name of the Event Hub to deploy under the Namespace')
param eventHubNamespaceHubName string

@maxValue(32)
@description('')
param eventHubNamespaceHubPartitionCount int = 2

@description('the amount of days to retain the event message')
param eventHubNamespaceHubMessageRetention int = 1

@description('The authorizaiton policies to deploy with the the event hub')
param eventHubNamespaceHubPolicies array = []

// **************************************************************************************** //
//                                  Event Hub Deployment                                    //
// **************************************************************************************** //

resource azEventHubDeployment 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: replace(replace('${eventHubNamespaceName}/${eventHubNamespaceHubName}', '@environment', environment), '@region', region)
  properties: {
    partitionCount: eventHubNamespaceHubPartitionCount
    messageRetentionInDays: eventHubNamespaceHubMessageRetention
  }
  resource azEventHubAuthorizationRulesDeployment 'AuthorizationRules' = [for policy in eventHubNamespaceHubPolicies: if (!empty(eventHubNamespaceHubPolicies)) {
    name: !empty(eventHubNamespaceHubPolicies) ? policy.policyName : 'no-policy-to-deploy'
    properties: {
      rights: !empty(eventHubNamespaceHubPolicies) ? policy.policyPermissions : []
    }
  }]
}
