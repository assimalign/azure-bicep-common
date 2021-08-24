@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the private endpoint to be deployed')
param privateEndpointName string

@description('The groups category for the private endpoint')
param privateEndpointGroupIds array

@description('The ResourceId to link the private endpoint to')
param privateEndpointLinkServiceId string

@description('The name of the Virtual Network Subnet the private endpoint belongs to')
param privateEndpointSubnet string

@description('The name of the Virtual Network the Subnet belongs to')
param privateEndpointSubnetVirtualNetwork string

@description('The name of the Resource Group the Subnet belongs to')
param privateEndpointSubnetResourceGroup string

@description('The name of the private DNS Zone')
param privateEndpointPrivateDnsZone string

@description('A descriptive group name to add to the private endpoint DNS configurations')
param privateEndpointPrivateDnsZoneGroupName string

@description('')
param privateEndpointPrivateDnsZoneResourceGroup string 




// 1. Get Existing Subnet Resource within a virtual network
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: replace('${privateEndpointSubnetVirtualNetwork}/${privateEndpointSubnet}', '@environment', environment)
  scope: resourceGroup(replace('${privateEndpointSubnetResourceGroup}', '@environment', environment))
}


// 2. Get the Private DNS Zone to attach toe Private DNS Zone Group in the endpoint
resource azPrivateDnsZoneResource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateEndpointPrivateDnsZone
  scope: resourceGroup(replace('${privateEndpointPrivateDnsZoneResourceGroup}', '@environment', environment))
}


// 3. Deploy the private endpoint
resource azPrivateEndpointDeployment 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: replace('${privateEndpointName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    privateLinkServiceConnections: [
      {
        name: replace('${privateEndpointName}', '@environment', environment)
        properties: {
          privateLinkServiceId: privateEndpointLinkServiceId
          groupIds: privateEndpointGroupIds
        }
      }
    ]
    subnet: {
      id: azVirtualNetworkSubnetResource.id
    }
  }
  dependsOn: [
    azPrivateDnsZoneResource
    azVirtualNetworkSubnetResource
  ]

  resource azPrivateEndpointPrivateDnsZoneGroupDeployment 'privateDnsZoneGroups' = {
    name: azPrivateDnsZoneResource.name
    properties: {
      privateDnsZoneConfigs: [
        {
          name: privateEndpointPrivateDnsZoneGroupName
          properties: {
            privateDnsZoneId: azPrivateDnsZoneResource.id
          }
        }
      ]
    }
    dependsOn: [
      azPrivateEndpointDeployment
    ]
  }
}
