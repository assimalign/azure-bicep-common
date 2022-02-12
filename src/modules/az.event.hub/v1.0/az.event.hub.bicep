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
param eventHubNamespace string

@description('The name of the Event Hub to deploy under the Namespace')
param eventHubName string

@maxValue(32)
@description('')
param eventHubPartitionCount int = 2

@description('the amount of days to retain the event message')
param eventHubMessageRetention int = 1

@description('The authorizaiton policies to deploy with the the event hub')
param eventHubPolicies array = []

// **************************************************************************************** //
//                                  Event Hub Deployment                                    //
// **************************************************************************************** //

resource azEventHubDeployment 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: replace(replace('${eventHubNamespace}/${eventHubName}', '@environment', environment), '@region', region)
  properties: {
    partitionCount: eventHubPartitionCount
    messageRetentionInDays: eventHubMessageRetention
  }

  resource azEventHubAuthorizationRulesDeployment 'AuthorizationRules' = [for policy in eventHubPolicies: if (!empty(policy)) {
    name: !empty(eventHubPolicies) ? policy.name : 'no-policy-to-deploy'
    properties: {
      rights: !empty(eventHubPolicies) ? policy.permissions : []
    }
  }]
}
