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

@description('')
param databricksWorkspaceName string

@description('')
param databricksWorkspaceSku object

@description('')
param databricksWorkspaceLocation string = resourceGroup().location

@description('')
param databricksWorkspaceConfigs object = {}

@description('')
param databricksWorkspacePrivateEndpoint object = {}

var workspaceName = replace(replace(databricksWorkspaceName, '@environment', environment), '@region', region)
var managedResourceGroupName = 'databricks-rg-${workspaceName}-${uniqueString(workspaceName, resourceGroup().id)}'

resource azDatabricksWorkspaceDeployment 'Microsoft.Databricks/workspaces@2022-04-01-preview' = {
  name: replace(replace(databricksWorkspaceName, '@environment', environment), '@region', region)
  location: databricksWorkspaceLocation
  sku: {
    name: contains(databricksWorkspaceSku, environment) ? databricksWorkspaceSku[environment] : databricksWorkspaceSku.default
  }
  properties: {
    publicNetworkAccess: contains(databricksWorkspaceConfigs, 'disablePublicNetworkAccess') && databricksWorkspaceConfigs.disablePublicNetworkAccess == true ? 'Disabled' : 'Enabled'
    parameters: {
      enableNoPublicIp: {
        value: contains(databricksWorkspaceConfigs, 'disablePublicIP') ? databricksWorkspaceConfigs.disablePublicIP : false
      }
    }
    managedResourceGroupId: managedResourceGroup.id
  }
}

resource managedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: managedResourceGroupName
}

// 4. Deploy Private Endpoint if applicable
module azEventGridPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(databricksWorkspacePrivateEndpoint)) {
  name: !empty(databricksWorkspacePrivateEndpoint) ? toLower('az-dbks-priv-endpoint-${guid('${azDatabricksWorkspaceDeployment.id}/${databricksWorkspacePrivateEndpoint.privateEndpointName}')}') : 'no-dbks-priv-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointLocation: contains(databricksWorkspacePrivateEndpoint, 'privateEndpointLocation') ? databricksWorkspacePrivateEndpoint.privateEndpointLocation : databricksWorkspaceLocation
    privateEndpointName: databricksWorkspacePrivateEndpoint.privateEndpointName
    privateEndpointDnsZoneGroupName: 'privatelink-azuredatabricks-net'
    privateEndpointDnsZoneName: databricksWorkspacePrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneResourceGroup: databricksWorkspacePrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: databricksWorkspacePrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: databricksWorkspacePrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: databricksWorkspacePrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azDatabricksWorkspaceDeployment.id
    privateEndpointTags: contains(databricksWorkspacePrivateEndpoint, 'privateEndpointTags') ? databricksWorkspacePrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'databricks_ui_api'
    ]
  }
}

output databricksWorkspace object = azDatabricksWorkspaceDeployment
