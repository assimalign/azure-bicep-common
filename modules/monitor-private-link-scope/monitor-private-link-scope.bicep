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
@description('The environment in which the resource(s) will be deployed.')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('')
param monitorPrivateLinkScopeName string

@description('')
param monitorPrivateLinkScopeLocation string = resourceGroup().location

@description('')
param monitorPrivateLinkScopePrivateEndpoint object = {}

@description('')
param monitorPrivateLinkScopeResources array

@description('')
param monitorPrivateLinkScopeConfig object = {
  queryAccessMode: 'Open'
  ingestionAccessMode: 'Open'
}

@description('The tags to attach to the resource when deployed')
param monitorPrivateLinkScopeTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

func formatId(name string, affix string, environment string, region string) string =>
  guid(formatName(name, affix, environment, region))

resource monitorPrivateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: formatName(monitorPrivateLinkScopeName, affix, environment, region)
  location: monitorPrivateLinkScopeLocation
  properties: {
    accessModeSettings: monitorPrivateLinkScopeConfig
  }
  resource scopeResources 'scopedResources' = [
    for resource in monitorPrivateLinkScopeResources: {
      name: formatId(resource.resourceName, affix, environment, region)
      properties: {
        linkedResourceId: resourceId(
          formatName(resource.resourceGroup, affix, environment, region),
          resource.resourceType,
          formatName(resource.resourceName, affix, environment, region)
        )
      }
    }
  ]
  tags: union(monitorPrivateLinkScopeTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

module privateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(monitorPrivateLinkScopePrivateEndpoint)) {
  name: !empty(monitorPrivateLinkScopePrivateEndpoint)
    ? toLower('apps-private-ep-${guid('${monitorPrivateLinkScope.id}/${monitorPrivateLinkScopePrivateEndpoint.privateEndpointName}')}')
    : 'no-app-sv-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    privateEndpointName: monitorPrivateLinkScopePrivateEndpoint.privateEndpointName
    privateEndpointLocation: monitorPrivateLinkScopePrivateEndpoint.?privateEndpointLocation ?? monitorPrivateLinkScopeLocation
    privateEndpointDnsZoneGroupConfigs: monitorPrivateLinkScopePrivateEndpoint.privateEndpointDnsZoneGroupConfigs
    privateEndpointVirtualNetworkName: monitorPrivateLinkScopePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: monitorPrivateLinkScopePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: monitorPrivateLinkScopePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: monitorPrivateLinkScope.id
    privateEndpointTags: monitorPrivateLinkScopePrivateEndpoint.?privateEndpointTags
    privateEndpointGroupIds: [
      'azuremonitor'
    ]
  }
}

output monitorPrivateLinkScope object = monitorPrivateLinkScope
