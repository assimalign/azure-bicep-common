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

@description('The name of the Event hub Resource to be deployed')
param eventHubNamespace string

@description('A list of Event Hubs to deploy under the Namespace')
param eventHubs array = []

@description('The pricing tier broken into per environment')
param eventHubSku object = {}

@description('A flag to endable System Managed Identity in Azure')
param eventHubEnableMsi bool = false

@minValue(1)
@maxValue(20)
@description('The total instance counts to be utilized')
param eventHubCapacity int = 1

@description('')
param eventHubPolicies array = []

// 1. Deploy Event Hub Namespace
resource azEventHubNamespaceDeployment 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: replace(replace('${eventHubNamespace}', '@environment', environment), '@region', region)
  location: resourceGroup().location
  identity: {
    type: eventHubEnableMsi == true && !empty(eventHubSku) ? 'SystemAssigned' : 'None'
  }
  sku: any(environment == 'dev' && !empty(eventHubSku) ? {
    name: eventHubSku.dev
    tier: eventHubSku.dev
    capacity: eventHubCapacity
  } : any(environment == 'qa' && !empty(eventHubSku) ? {
    name: eventHubSku.dev
    tier: eventHubSku.dev
    capacity: eventHubCapacity
  } : any(environment == 'uat' && !empty(eventHubSku) ? {
    name: eventHubSku.dev
    tier: eventHubSku.dev
    capacity: eventHubCapacity
  } : any(environment == 'prd' && !empty(eventHubSku) ? {
    name: eventHubSku.prd
    tier: eventHubSku.prd
    capacity: eventHubCapacity
  } : {
    name: 'Basic'
    tier: 'Basic'
    capacity: 1
  }))))

  resource azEventHubNamespaceAuthorizationRulesDeployment 'AuthorizationRules' = [for (policy, index) in eventHubPolicies: if (!empty(policy)) {
    name: !empty(eventHubPolicies) ? policy.name : 'no-policy'
    properties: {
      rights: !empty(eventHubPolicies) ? policy.permissions : []
    }
  }]
}

// 2 Deploy individual Event Hubs under the Event Hub Namespace
module azEventHubsDeployment 'az.event.hub.bicep' = [for (hub, index) in eventHubs: if (!empty(hub)) {
  name: !empty(eventHubs) ? toLower('az-ehn-hub-${guid('${azEventHubNamespaceDeployment.id}/${hub.name}')}') : 'no-eh-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    eventHubName: hub.name
    eventHubNamespace: eventHubNamespace
    eventHubMessageRetention: hub.messageRetention
    eventHubPartitionCount: hub.partitionCount
    eventHubPolicies: hub.policies
  }
}]
