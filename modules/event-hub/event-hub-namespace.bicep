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

@description('The name of the Event hub Resource to be deployed')
param eventHubNamespaceName string

@description('')
param eventHubNamespaceLocation string = resourceGroup().location

@description('A list of Event Hubs to deploy under the Namespace')
param eventHubNamespaceHubs array = []

@description('The pricing tier broken into per environment')
param eventHubNamespaceSku object = {
  dev: 'Basic'
  qa: 'Basic'
  uat: 'Basic'
  prd: 'Basic'
  default: 'Basic'
}

@description('A flag to endable System Managed Identity in Azure')
param eventHubNamespaceEnableMsi bool = false

@minValue(1)
@maxValue(20)
@description('The total instance counts to be utilized')
param eventHubNamespaceCapacity int = 1

@description('')
param eventHubNamespacePolicies array = []

@description('')
param eventHubNamespaceTags object = {}

// 1. Deploy Event Hub Namespace
resource azEventHubNamespaceDeployment 'Microsoft.EventHub/namespaces@2024-05-01-preview' = {
  name: replace(replace(replace(eventHubNamespaceName, '@affix', affix), '@environment', environment), '@region', region)
  location: eventHubNamespaceLocation
  identity: {
    type: eventHubNamespaceEnableMsi == true && !empty(eventHubNamespaceSku) ? 'SystemAssigned' : 'None'
  }
  sku: contains(eventHubNamespaceSku, environment) ? {
    name: eventHubNamespaceSku[environment]
    tier: eventHubNamespaceSku[environment]
    capacity: eventHubNamespaceCapacity
  } : {
    name: eventHubNamespaceSku.default
    tier: eventHubNamespaceSku.default
    capacity: 1
  }
  resource azEventHubNamespaceAuthorizationRulesDeployment 'AuthorizationRules' = [for (policy, index) in eventHubNamespacePolicies: if (!empty(eventHubNamespacePolicies)) {
    name: !empty(eventHubNamespacePolicies) ? policy.policyName : 'no-policy-to-deploy'
    properties: {
      rights: !empty(eventHubNamespacePolicies) ? policy.policyPermissions : []
    }
  }]
  tags: union(eventHubNamespaceTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

// 2 Deploy individual Event Hubs under the Event Hub Namespace
module azEventHubsDeployment 'event-hub-namespace-hub.bicep' = [for (hub, index) in eventHubNamespaceHubs: if (!empty(hub)) {
  name: !empty(eventHubNamespaceHubs) ? toLower('ehn-hub-${guid('${azEventHubNamespaceDeployment.id}/${hub.eventHubNamespaceHubName}')}') : 'no-eh-to-deploy'
  params: {
    affix: affix
    region: region
    environment: environment
    eventHubNamespaceName: eventHubNamespaceName
    eventHubNamespaceHubName: hub.eventHubNamespaceHubName
    eventHubNamespaceHubMessageRetention: hub.eventHubNamespaceHubMessageRetention
    eventHubNamespaceHubPartitionCount: hub.eventHubNamespaceHubPartitionCount
    eventHubNamespaceHubPolicies: hub.eventHubNamespaceHubPolicies
  }
}]

output eventHubNamespace object = azEventHubNamespaceDeployment
