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
resource azEventHubNamespaceDeployment 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: replace(replace(eventHubNamespaceName, '@environment', environment), '@region', region)
  location: eventHubNamespaceLocation
  identity: {
    type: eventHubNamespaceEnableMsi == true && !empty(eventHubNamespaceSku) ? 'SystemAssigned' : 'None'
  }
  sku: any(environment == 'dev' && !empty(eventHubNamespaceSku) ? {
    name: eventHubNamespaceSku.dev
    tier: eventHubNamespaceSku.dev
    capacity: eventHubNamespaceCapacity
  } : any(environment == 'qa' && !empty(eventHubNamespaceSku) ? {
    name: eventHubNamespaceSku.dev
    tier: eventHubNamespaceSku.dev
    capacity: eventHubNamespaceCapacity
  } : any(environment == 'uat' && !empty(eventHubNamespaceSku) ? {
    name: eventHubNamespaceSku.dev
    tier: eventHubNamespaceSku.dev
    capacity: eventHubNamespaceCapacity
  } : any(environment == 'prd' && !empty(eventHubNamespaceSku) ? {
    name: eventHubNamespaceSku.prd
    tier: eventHubNamespaceSku.prd
    capacity: eventHubNamespaceCapacity
  } : {
    name: eventHubNamespaceSku.default
    tier: eventHubNamespaceSku.default
    capacity: 1
  }))))

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
module azEventHubsDeployment 'eventHubNamespaceHub.bicep' = [for (hub, index) in eventHubNamespaceHubs: if (!empty(hub)) {
  name: !empty(eventHubNamespaceHubs) ? toLower('az-ehn-hub-${guid('${azEventHubNamespaceDeployment.id}/${hub.eventHubNamespaceHubName}')}') : 'no-eh-to-deploy'
  scope: resourceGroup()
  params: {
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
