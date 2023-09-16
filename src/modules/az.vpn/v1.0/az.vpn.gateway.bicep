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

@description('The name of the VPN Gateway')
param vpnGatewayName string

@description('')
param vpnGatewayLocation string = resourceGroup().location

@allowed([
   'PolicyBased'
   'RouteBased'
])
@description('')
param vpnGatewayNetworkType string

@description('The Name of the new Public IP Address that will be deployed for the VPN Gateway')
param vpnGatewayIpName string

@description('The name of the Virtual Network to use for the VPN Gateway')
param vpnGatewayVirtualNetworkName string

@description('The VPN Gateway Pricing Tier to deploy')
param vpnGatewaySku object

@description('The VPN Client settings for connecting to the Virtual Network')
param vpnGatewayClientSettings object = {}

// 1. Get Gateway Subnet within specified Virtual Network
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
   name: replace(replace('${vpnGatewayVirtualNetworkName}/GatewaySubnet', '@environment', environment), '@region', region)
}

// 2. Create Public IP Address fo VPN Gateway
resource azVirtualNetworkGatewayPublicIpDeployment 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
   name: replace(replace(vpnGatewayIpName, '@environment', environment), '@region', region)
   location: vpnGatewayLocation
   sku: {
      name: 'Basic'
      tier: 'Regional'
   }
   properties: {
      publicIPAllocationMethod: 'Dynamic'
   }
}

resource azVirtualNetworkGatewayDeployment 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
   name: replace(replace('${vpnGatewayName}', '@environment', environment), '@region', region)
   location: vpnGatewayLocation
   properties: {
      gatewayType: 'Vpn'
      vpnType: vpnGatewayNetworkType
      sku: contains(vpnGatewaySku, environment) ? {
         name: vpnGatewaySku[environment]
         tier: vpnGatewaySku[environment]
      } : {
         name: vpnGatewaySku.default
         tier: vpnGatewaySku.default
      }
      ipConfigurations: [
         {
            name: 'default'
            properties: {
               privateIPAllocationMethod: 'Dynamic'
               publicIPAddress: {
                  id: azVirtualNetworkGatewayPublicIpDeployment.id
               }
               subnet: {
                  id: azVirtualNetworkSubnetResource.id
               }
            }
         }
      ]
      enableBgp: false
      activeActive: false
      vpnClientConfiguration: any(empty(vpnGatewayClientSettings) ? {
         // Set an Empty Object if no Client Settings are passed
      } : any(vpnGatewayClientSettings.authentication == 'AzureActiveDirectory' ? {
         vpnClientAddressPool: {
            addressPrefixes: [
               vpnGatewayClientSettings.addressPool
            ]
         }
         vpnClientProtocols: [
            'OpenVPN'
         ]
         aadTenant: 'https://login.microsoftonline.com/${subscription().tenantId}/'
         aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
         aadIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
      } : {}))
   }
   
   dependsOn: [
      azVirtualNetworkSubnetResource
   ]
}
