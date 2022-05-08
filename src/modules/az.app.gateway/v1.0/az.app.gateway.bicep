@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed.')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Azure App Gateway.')
param appGatewayName string

@description('The location/region the Azure App Gateway will be deployed to.')
param appGatewayLocation string = resourceGroup().location

@description('The pricing tier of the Azure App Gateway.')
param appGatewaySku object

@description('')
param appGatewayBackend object

@description('')
param appGatewayFrontend object

@description('The Azure App Gateway routing rules. Reference Link: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-request-routing-rules')
param appGatewayRoutingRules array

// **************************************************************************************** //
//                              App Gateway Deployment                                      //
// **************************************************************************************** //
// 1. Get Virtual Network Subnet to reference for Ip Configurations
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: replace(replace('${appGatewayFrontend.privateIp.privateIpVirtualNetwork}/${appGatewayFrontend.privateIp.privateIpSubnet}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace('${appGatewayFrontend.privateIp.privateIpResourceGroup}', '@environment', environment), '@region', region))
}

// 2. Get a Public IP address for the frontend of the gateway if applicable
resource azPublicIpAddressNameResource 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = if (!empty(appGatewayFrontend.publicIp)) {
  name: replace(replace('${appGatewayFrontend.publicIp.publicIpName}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace('${appGatewayFrontend.publicIp.publicIpResourceGroup}', '@environment', environment), '@region', region))
}

// Format the Backend Pool
var backendAddressPools = [for pool in appGatewayBackend.receivers: {
  name: pool.name
  properties: {
    backendAddresses: environment == 'dev' ? pool.addresses.dev : environment == 'qa' ? pool.addresses.qa : environment == 'uat' ? pool.addresses.uat : pool.addresses.prd
  }
}]

//
var backendPorts = [for port in appGatewayBackend.ports: {
  name: port.name
  properties: {
    cookieBasedAffinity: 'Disabled'
    port: port.backendPort
    protocol: port.backendProtocol
    requestTimeout: port.backendRequestTimeout
  }
}]

// Format Frontend Ports to receive requests on
var frontenPorts = [for port in appGatewayFrontend.ports: {
  name: port.name
  properties: {
    port: port.frontendPort
  }
}]

// format HttpListener Vairables
var frontendHttpListeners = [for listener in appGatewayFrontend.listeners: {
  name: listener.name
  properties: {
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace(replace('${appGatewayName}', '@environment', environment), '@region', region))}/frontendIPConfigurations/${listener.frontendIp}'
    }
    frontendPort: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace(replace('${appGatewayName}', '@environment', environment), '@region', region))}/frontendPorts/${listener.frontendPort}'
    }
    protocol: listener.frontendProtocol
    sslCertificate: null
  }
}]

//
var routingRules = [for rule in appGatewayRoutingRules: {
  name: rule.name
  properties: {
    ruleType: rule.routeType
    httpListener: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace(replace('${appGatewayName}', '@environment', environment), '@region', region))}/httpListeners/${rule.routeFromHttpListener}'
    }
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace(replace('${appGatewayName}', '@environment', environment), '@region', region))}/backendAddressPools/${rule.routeToBackendPool}'
    }
    backendHttpSettings: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace(replace('${appGatewayName}', '@environment', environment), '@region', region))}/backendHttpSettingsCollection/${rule.routeToBackendPort}'
    }
  }
}]

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: replace(replace('${appGatewayName}', '@environment', environment), '@region', region)
  location: appGatewayLocation
  properties: {
    sku: any(environment == 'dev' ? {
      name: '${appGatewaySku.dev.tier}_${appGatewaySku.dev.size}'
      tier: appGatewaySku.dev.tier
      capacity: appGatewaySku.dev.capacity
    } : any(environment == 'qa' ? {
      name: '${appGatewaySku.qa.tier}_${appGatewaySku.qa.size}'
      tier: appGatewaySku.qa.tier
      capacity: appGatewaySku.qa.capacity
    } : any(environment == 'uat' ? {
      name: '${appGatewaySku.uat.tier}_${appGatewaySku.uat.size}'
      tier: appGatewaySku.uat.tier
      capacity: appGatewaySku.uat.capacity
    } : any(environment == 'prd' ? {
      name: '${appGatewaySku.prd.tier}_${appGatewaySku.prd.size}'
      tier: appGatewaySku.prd.tier
      capacity: appGatewaySku.prd.capacity
    } : {
      name: 'Standard_Small'
      tier: 'Standard'
      capacity: 2
    }))))
    gatewayIPConfigurations: [
      {
        name: replace(replace('${appGatewayName}-ip-configuration', '@environment', environment), '@region', region)
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ]
    frontendIPConfigurations: any(!empty(appGatewayFrontend.publicIp) && !empty(appGatewayFrontend.privateIp) ? [
      {
        name: appGatewayFrontend.publicIp.name
        properties: {
          publicIPAddress: {
            id: azPublicIpAddressNameResource.id
          }
        }
      }
      {
        name: appGatewayFrontend.privateIp.name
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontend.publicIp) ? [
      {
        name: appGatewayFrontend.publicIp.name
        properties: {
          publicIPAddress: {
            id: azPublicIpAddressNameResource.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontend.privateIp) ? [
      {
        name: appGatewayFrontend.privateIp.name
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ] : [])))
    frontendPorts: frontenPorts
    httpListeners: frontendHttpListeners
    backendAddressPools: backendAddressPools
    backendHttpSettingsCollection: backendPorts
    requestRoutingRules: routingRules
  }
}


output appGateway object = applicationGateway
