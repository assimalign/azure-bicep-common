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
 
 @minLength(3)
 @maxLength(3)
 @description('The Name of the new Public IP Address that will be deployed for the VPN Gateway')
 param vpnGatewayIpAddresses array
 
 @description('The name of the Virtual Network to use for the VPN Gateway, Ensure that a GatewaySubnet is created within the virtual network.')
 param vpnGatewayVirtualNetworkName string
 
 @description('The VPN Gateway Pricing Tier to deploy')
 param vpnGatewaySku object
 
 @description('The VPN Client settings for connecting to the Virtual Network')
 param vpnGatewayClientSettings object = {}
 
 func format(name string, environment string, region string) string =>
   replace(replace(name, '@environment', environment), '@region', region)
 
 // 1. Get Gateway Subnet within specified Virtual Network
 resource virtualNetworkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
   name: replace(
     replace('${vpnGatewayVirtualNetworkName}/GatewaySubnet', '@environment', environment),
     '@region',
     region
   )
 }
 
 // 2. Create Public IP Address fo VPN Gateway
 resource ipAddressOne 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
   name: format(vpnGatewayIpAddresses[0].ipAddressName, environment, region)
   scope: resourceGroup(format(vpnGatewayIpAddresses[0].ipAddressResourceGroup, environment, region))
 }
 
 resource ipAddressTwo 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
   name: format(vpnGatewayIpAddresses[1].ipAddressName, environment, region)
   scope: resourceGroup(format(vpnGatewayIpAddresses[1].ipAddressResourceGroup, environment, region))
 }
 
 resource ipAddressThree 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
    name: format(vpnGatewayIpAddresses[2].ipAddressName, environment, region)
    scope: resourceGroup(format(vpnGatewayIpAddresses[2].ipAddressResourceGroup, environment, region))
  }
 
 resource vpn 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
   name: replace(replace(vpnGatewayName, '@environment', environment), '@region', region)
   location: vpnGatewayLocation
   properties: {
     gatewayType: 'Vpn'
     vpnType: vpnGatewayNetworkType
     enableDnsForwarding: true
     sku: contains(vpnGatewaySku, environment)
       ? {
           name: vpnGatewaySku[environment]
           tier: vpnGatewaySku[environment]
         }
       : {
           name: vpnGatewaySku.default
           tier: vpnGatewaySku.default
         }
     ipConfigurations: [
       {
         name: 'default'
         properties: {
           privateIPAllocationMethod: 'Dynamic'
           publicIPAddress: {
             id: ipAddressOne.id
           }
           subnet: {
             id: virtualNetworkSubnet.id
           }
         }
       }
       {
         name: 'activeActive'
         properties: {
           privateIPAllocationMethod: 'Dynamic'
           publicIPAddress: {
             id: ipAddressTwo.id
           }
           subnet: {
             id: virtualNetworkSubnet.id
           }
         }
       }
       {
          name: format(vpnGatewayIpAddresses[2].ipAddressName, environment, region)
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            publicIPAddress: {
              id: ipAddressThree.id
            }
            subnet: {
              id: virtualNetworkSubnet.id
            }
          }
        }
     ]
     enableBgp: false
     activeActive: true
     vpnClientConfiguration: any(empty(vpnGatewayClientSettings)
       ? {
           // Set an Empty Object if no Client Settings are passed
         }
       : any(vpnGatewayClientSettings.authentication == 'AzureActiveDirectory'
           ? {
               vpnClientAddressPool: {
                 addressPrefixes: [
                   vpnGatewayClientSettings.addressPool
                 ]
               }
               vpnClientProtocols: [
                 'OpenVPN'
               ]
               aadTenant: '${az.environment().authentication.loginEndpoint}${subscription().tenantId}'
               aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
               aadIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
             }
           : {}))
   }
 
   dependsOn: [
     virtualNetworkSubnet
   ]
 }
 
 output vpnGateway object = vpn
 