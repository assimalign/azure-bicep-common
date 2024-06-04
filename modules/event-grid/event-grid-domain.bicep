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

@description('The name of the Event Grid Domain to deploy')
param eventGridDomainName string

@description('The location/region the Azure Event Grid Domain will be deployed to.')
param eventGridDomainLocation string = resourceGroup().location

@description('A list of object with the Topics and Subscriptions to be deployed under the Event Grid Resource')
param eventGridDomainTopics array = []

@description('Configurations for implementing a Private Endpoint for the Event Grid Domain')
param eventGridDomainPrivateEndpoint object = {}

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridDomainMsiEnabled bool = false

@description('A flag to indicate whether System Managed Identity should be enabled for this resource')
param eventGridDomainMsiRoleAssignments array = []

@description('Network settings for the devent grid domain.')
param eventGridNetworkSettings object = {}

@description('')
param eventGridDomainTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)


// 1. Deploy Event Grid Domain
resource egd 'Microsoft.EventGrid/domains@2022-06-15' = {
  name: formatName(eventGridDomainName, affix, environment, region)
  location: eventGridDomainLocation
  identity: {
    type: eventGridDomainMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: eventGridNetworkSettings.?allowPublicNetworkAccess ?? 'Enabled'
  }
  tags: union(eventGridDomainTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 2. Deploy Event Grid Topic & Topic Subscriptions
module egdTopics 'event-grid-domain-topic.bicep' = [for (topic, index) in eventGridDomainTopics: if (!empty(topic)) {
  name: !empty(eventGridDomainTopics) ? toLower('egd-topic-${guid('${egd.id}/${topic.eventGridDomainTopicName}')}') : 'no-egd-topics-to-deploy'
  params: {
    affix: affix
    region: region
    environment: environment
    eventGridDomainName: eventGridDomainName
    eventGridDomainTopicName: topic.eventGridDomainTopicName
    eventGridDomainTopicSubscriptions: topic.?eventGridDomainTopicSubscriptions
  }
  dependsOn: [
    egdRoleAssignment // If using System Managed Identity
  ]
}]

// 4. Deploy Private Endpoint if applicable
module egdPrivateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(eventGridDomainPrivateEndpoint)) {
  name: !empty(eventGridDomainPrivateEndpoint) ? toLower('egd-private-ep-${guid('${egd.id}/${eventGridDomainPrivateEndpoint.privateEndpointName}')}') : 'no-egd-private-endpoint-to-deploy'
  params: {
    affix: affix
    region: region
    environment: environment
    privateEndpointLocation: eventGridDomainPrivateEndpoint.?privateEndpointLocation ?? eventGridDomainLocation
    privateEndpointName: eventGridDomainPrivateEndpoint.privateEndpointName
    privateEndpointDnsZoneGroupConfigs: eventGridDomainPrivateEndpoint.privateEndpointDnsZoneGroupConfigs
    privateEndpointVirtualNetworkName: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: eventGridDomainPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: egd.id
    privateEndpointTags: eventGridDomainPrivateEndpoint.?privateEndpointTags 
    privateEndpointGroupIds: [
      'domain'
    ]
  }
}

// 9.  Assignment RBAC Roles, if any, to App Service Slot Service Principal  
module egdRoleAssignment '../rbac/rbac.bicep' = [for roleAssignment in eventGridDomainMsiRoleAssignments: if (eventGridDomainMsiEnabled == true && !empty(eventGridDomainMsiRoleAssignments)) {
  name: 'egd-rbac-${guid('${egd.name}-${roleAssignment.resourceRoleName}')}'
  scope: resourceGroup(formatName(roleAssignment.resourceGroupToScopeRoleAssignment, affix, environment, region))
  params: {
    affix: affix
    region: region
    environment: environment
    resourceRoleName: roleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: roleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: roleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: roleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: roleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: egd.identity.principalId
  }
}]


output eventGridDomain object = egd
