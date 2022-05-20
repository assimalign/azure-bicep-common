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

@description('The name of the private endpoint to be deployed')
param privateEndpointName string

@description('The location/region the Azure Private Enpoint will be deployed to.')
param privateEndpointLocation string = resourceGroup().location

@description('The groups category for the private endpoint')
param privateEndpointGroupIds array

@description('The ResourceId to link the private endpoint to')
param privateEndpointResourceIdLink string

@description('The name of the Virtual Network the Subnet belongs to')
param privateEndpointVirtualNetworkName string

@description('The name of the Virtual Network Subnet the private endpoint belongs to')
param privateEndpointVirtualNetworkSubnetName string

@description('The name of the Resource Group the Subnet belongs to')
param privateEndpointVirtualNetworkResourceGroup string

@description('The name of the private DNS Zone')
param privateEndpointDnsZoneName string

@description('The name of the resource group the private DNS zone belongs to.')
param privateEndpointDnsZoneResourceGroup string

@description('A descriptive group name to add to the private endpoint DNS configurations')
param privateEndpointDnsZoneGroupName string

@description('')
param privateEndpointTags object = {}

// 1. Get Existing Subnet Resource within a virtual network
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: replace(replace('${privateEndpointVirtualNetworkName}/${privateEndpointVirtualNetworkSubnetName}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(privateEndpointVirtualNetworkResourceGroup, '@environment', environment), '@region', region))
}

// 2. Get the Private DNS Zone to attach toe Private DNS Zone Group in the endpoint
resource azPrivateDnsZoneResource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateEndpointDnsZoneName
  scope: resourceGroup(replace(replace(privateEndpointDnsZoneResourceGroup, '@environment', environment), '@region', region))
}

// 3. Deploy the private endpoint
resource azPrivateEndpointDeployment 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: replace(replace(privateEndpointName, '@environment', environment), '@region', region)
  location: privateEndpointLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: replace(replace(privateEndpointName, '@environment', environment), '@region', region)
        properties: {
          privateLinkServiceId: replace(replace(replace(privateEndpointResourceIdLink, '@environment', environment), '@region', region), '@subscription', subscription().subscriptionId)
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
          name: privateEndpointDnsZoneGroupName
          properties: {
            privateDnsZoneId: azPrivateDnsZoneResource.id
          }
        }
      ]
    }
  }
  tags: union(privateEndpointTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 4. Return Deployment ouput
output resource object = azPrivateEndpointDeployment
