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

func formatId(name string, environment string, region string) string =>
  guid(replace(replace(name, '@environment', environment), '@region', region))

func formatName(name string, environment string, region string) string =>
  replace(replace(name, '@environment', environment), '@region', region)

resource monitorPrivateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: formatName(monitorPrivateLinkScopeName, environment, region)
  location: monitorPrivateLinkScopeLocation
  properties: {
    accessModeSettings: monitorPrivateLinkScopeConfig
  }
  resource scopeResources 'scopedResources' = [for resource in monitorPrivateLinkScopeResources: {
    name: formatId(resource.resourceName, environment, region)
    properties: {
       linkedResourceId: resourceId(
        resource.resourceGroup,
        '',
        resource.resourceName
       )
    }
  }]
}

module privateEndpoint '../private-endpoint/private-endpoint.bicep' = if (!empty(monitorPrivateLinkScopePrivateEndpoint)) {
  name: !empty(monitorPrivateLinkScopePrivateEndpoint)
    ? toLower('apps-private-ep-${guid('${monitorPrivateLinkScope.id}/${monitorPrivateLinkScopePrivateEndpoint.privateEndpointName}')}')
    : 'no-app-sv-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: monitorPrivateLinkScopePrivateEndpoint.privateEndpointName
    privateEndpointLocation: monitorPrivateLinkScopePrivateEndpoint.?privateEndpointLocation ?? monitorPrivateLinkScopeLocation
    privateEndpointDnsZoneName: monitorPrivateLinkScopePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-monitor-azure-com'
    privateEndpointDnsZoneResourceGroup: monitorPrivateLinkScopePrivateEndpoint.privateEndpointDnsZoneResourceGroup
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
