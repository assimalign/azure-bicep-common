@allowed([
   'dev'
   'qa'
   'uat'
   'prd'
 ])
 @description('The environment in which the resource(s) will be deployed')
 param environment string
 
 @description('The name of the VPN Gateway')
 param vpnName string

 @allowed([
    'PolicyBased'
    'RouteBased'
 ])
 @description('')
 param vpnType string

 @description('The Name of the new Public IP Address that will be deployed for the VPN Gateway')
 param vpnIpName string

 @description('The name of the Virtual Network to use for the VPN Gateway')
 param vpnVirtualNetworkName string

@description('The VPN Gateway Pricing Tier to deploy')
param vpnSku object

@description('The VPN Client settings for connecting to the Virtual Network')
param vpnClientSettings object = { }



// 1. Get Gateway Subnet within specified Virtual Network
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
   name: replace('${vpnVirtualNetworkName}/GatewaySubnet', '@environment', environment)
}


// 2. Create Public IP Address fo VPN Gateway
resource azVirtualNetworkGatewayPublicIpDeployment 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: replace('${vpnIpName}', '@environment', environment)
  location: resourceGroup().location
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
  properties: {
     publicIPAllocationMethod: 'Dynamic'
  }
}


resource azVirtualNetworkGatewayDeployment 'Microsoft.Network/virtualNetworkGateways@2021-02-01'= {
   name: replace('${vpnName}', '@environment', environment)
   location:resourceGroup().location
   properties: {
      gatewayType: 'Vpn'
      vpnType: vpnType
      sku: any(environment == 'dev' ? {
         name: vpnSku.dev
         tier: vpnSku.dev
      }: any(environment == 'qa' ? {
         name: vpnSku.qa
         tier: vpnSku.qa
      }: any(environment == 'uat' ? {
         name: vpnSku.uat
         tier: vpnSku.uat
      }: any(environment == 'prd' ? {
         name: vpnSku.prd
         tier: vpnSku.prd
      }: {
         name: 'VpnGw1'
         tier: 'VpnGw1'
      }))))
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
      vpnClientConfiguration:  any(empty(vpnClientSettings) ? { 
         // Set an Empty Object if no Client Settings are passed
      } : any(vpnClientSettings.authentication == 'AzureActiveDirectory' ? {
         vpnClientAddressPool: {
            addressPrefixes: [
               vpnClientSettings.addressPool
            ]
         }
         vpnClientProtocols: [
            'OpenVPN'
         ]
         aadTenant: 'https://login.microsoftonline.com/${subscription().tenantId}/'
         aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
         aadIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
         }: { }))
      }
      dependsOn: [
         azVirtualNetworkSubnetResource
         azVirtualNetworkGatewayPublicIpDeployment
      ]
}
