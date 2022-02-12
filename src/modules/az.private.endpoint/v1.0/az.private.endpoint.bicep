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
  name: replace(replace('${privateEndpointSubnetVirtualNetwork}/${privateEndpointSubnet}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace('${privateEndpointSubnetResourceGroup}', '@environment', environment), '@region', region))
}

// 2. Get the Private DNS Zone to attach toe Private DNS Zone Group in the endpoint
resource azPrivateDnsZoneResource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateEndpointPrivateDnsZone
  scope: resourceGroup(replace(replace('${privateEndpointPrivateDnsZoneResourceGroup}', '@environment', environment), '@region', region))
}

// 3. Deploy the private endpoint
resource azPrivateEndpointDeployment 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: replace(replace('${privateEndpointName}', '@environment', environment), '@region', region)
  location: resourceGroup().location
  properties: {
    privateLinkServiceConnections: [
      {
        name: replace(replace('${privateEndpointName}', '@environment', environment), '@region', region)
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
  }
}

// 4. Return Deployment ouput
output resource object = azPrivateEndpointDeployment
