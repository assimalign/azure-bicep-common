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

@description('The name of the Azure Cognitive Search Service to be deployed.')
param cognitiveSearchName string

@description('The location the Azure Cognitive Search Service will be deployed to.')
param cognitiveSearchLocation string = resourceGroup().location

@description('The pricing tier of the Azure Cognitive Search Service.')
param cognitiveSearchSku object = {
  dev: 'free'
  qa: 'free'
  uat: 'free'
  prd: 'free'
  default: 'free'
}

@allowed([
  'default'
  'highDensity'
])
@description('Applicable only for the standard3 SKU. You can set this property to enable up to 3 high density partitions that allow up to 1000 indexes, which is much higher than the maximum indexes allowed for any other SKU. For the standard3 SKU, the value is either default or highDensity. For all other SKUs, this value must be default.')
param cognitiveSearchHostingMode string = 'default'

@description('Specifies whether public network access should be enabled or diabled. False is the default.')
param cognitiveSearchDisablePublicAccess bool = true

@description('')
param cognitiveSearchMsiEnabled bool = false

@description('')
param cognitiveSearchMsiRoleAssignments array = []

@description('')
param cognitiveSearchPrivateEndpoint object = {}

@description('The tags to attach to the resource when deployed.')
param cognitiveSearchTags object = {}

var skuName = contains(cognitiveSearchSku, environment) ? cognitiveSearchSku[environment] : cognitiveSearchSku.default

// 1. Deploy Cognitive Search
resource azCognitiveSearchDeployment 'Microsoft.Search/searchServices@2020-08-01' = {
  name: replace(replace(cognitiveSearchName, '@environment', environment), '@region', region)
  location: cognitiveSearchLocation
  sku: {
    name: skuName
  }
  identity: {
    type: cognitiveSearchMsiEnabled == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    hostingMode: cognitiveSearchHostingMode
    publicNetworkAccess: cognitiveSearchDisablePublicAccess && skuName != 'free' ? 'disabled' : 'enabled'
  }
  tags: union(cognitiveSearchTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

module azAppServiceRoleAssignment '../../az.rbac/v1.0/az.rbac.role.assignment.bicep' = [for appRoleAssignment in cognitiveSearchMsiRoleAssignments: if (cognitiveSearchMsiEnabled == true && !empty(cognitiveSearchMsiRoleAssignments)) {
  name: 'az-cog-srch-rbac-${guid('${cognitiveSearchName}-${appRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: appRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: azCognitiveSearchDeployment.identity.principalId
  }
}]

// 2. Deploys a private endpoint, if applicable, for an instance of Azure Cognitive Search
module azAppConfigurationPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(cognitiveSearchPrivateEndpoint)) {
  name: !empty(cognitiveSearchPrivateEndpoint) ? toLower('az-search-pri-endp-${guid('${azCognitiveSearchDeployment.id}/${cognitiveSearchPrivateEndpoint.privateEndpointName}')}') : 'no-app-cfg-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: cognitiveSearchPrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(cognitiveSearchPrivateEndpoint, 'privateEndpointLocation') ? cognitiveSearchPrivateEndpoint.privateEndpointLocation : cognitiveSearchLocation
    privateEndpointDnsZoneName: cognitiveSearchPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-search-windows-net'
    privateEndpointDnsZoneResourceGroup: cognitiveSearchPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: cognitiveSearchPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: cognitiveSearchPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: cognitiveSearchPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azCognitiveSearchDeployment.id
    privateEndpointTags: contains(cognitiveSearchPrivateEndpoint, 'privateEndpointTags') ? cognitiveSearchPrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'searchService'
    ]
  }
}

output cognitiveSearch object = azCognitiveSearchDeployment
