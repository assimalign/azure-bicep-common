@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('')
param appGatewayName string

@description('')
param appGatewaySku object

@description('')
param appGatewayBackendConfigurations object

@description('')
param appGatewayFrontendConfigurations object

@description('')
param appGatewayRoutingRules array



// **************************************************************************************** //
//                              App Gateway Deployment                                      //
// **************************************************************************************** //
// 1. Get Virtual Network Subnet to reference for Ip Configurations
resource azVirtualNetworkSubnetResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: replace('${appGatewayFrontendConfigurations.privateIp.privateIpVirtualNetwork}/${appGatewayFrontendConfigurations.privateIp.privateIpSubnet}', '@environment', environment)
  scope: resourceGroup(replace('${appGatewayFrontendConfigurations.privateIp.privateIpResourceGroup}', '@environment', environment))
}

// 2. Get a Public IP address for the frontend of the gateway if applicable
resource azPublicIpAddressNameResource 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = if (!empty(appGatewayFrontendConfigurations.publicIp)) {
  name: replace('${appGatewayFrontendConfigurations.publicIp.publicIpName}', '@environment', environment)
  scope: resourceGroup(replace('${appGatewayFrontendConfigurations.publicIp.publicIpResourceGroup}', '@environment', environment))
}

// Format the Backend Pool
var backendAddressPools = [for pool in appGatewayBackendConfigurations.receivers: {
  name: pool.name
  properties: {
    backendAddresses: environment == 'dev' ? pool.addresses.dev : environment == 'qa' ? pool.addresses.qa : environment == 'uat' ? pool.addresses.uat : pool.addresses.prd
  }
}]

//
var backendPorts = [for port in appGatewayBackendConfigurations.ports: {
  name: port.name
  properties: {
    cookieBasedAffinity: 'Disabled'
    port: port.backendPort
    protocol: port.backendProtocol
    requestTimeout: port.backendRequestTimeout   
  }
}]

// Format Frontend Ports to receive requests on
var frontenPorts = [for port in appGatewayFrontendConfigurations.ports: {
  name: port.name
  properties: {
    port: port.frontendPort
  }
}]

// format HttpListener Vairables
var frontendHttpListeners = [for listener in appGatewayFrontendConfigurations.listeners: {
  name: listener.name
  properties: {
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace('${appGatewayName}', '@environment', environment))}/frontendIPConfigurations/${listener.frontendIp}'
    }
    frontendPort: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace('${appGatewayName}', '@environment', environment))}/frontendPorts/${listener.frontendPort}'
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
      id: '${resourceId('Microsoft.Network/applicationGateways', replace('${appGatewayName}', '@environment', environment))}/httpListeners/${rule.routeFromHttpListener}'
    }
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace('${appGatewayName}', '@environment', environment))}/backendAddressPools/${rule.routeToBackendPool}'
    }
    backendHttpSettings: {
      id: '${resourceId('Microsoft.Network/applicationGateways', replace('${appGatewayName}', '@environment', environment))}/backendHttpSettingsCollection/${rule.routeToBackendPort}'
    }
  }
}]

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: replace('${appGatewayName}', '@environment', environment)
  location: resourceGroup().location
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
        name: replace('${appGatewayName}-ip-configuration', '@environment', environment)
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ]
    frontendIPConfigurations: any(!empty(appGatewayFrontendConfigurations.publicIp) && !empty(appGatewayFrontendConfigurations.privateIp) ? [
      {
        name: appGatewayFrontendConfigurations.publicIp.name
        properties: {
          publicIPAddress: {
            id: azPublicIpAddressNameResource.id
          }
        }
      }
      {
        name: appGatewayFrontendConfigurations.privateIp.name
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontendConfigurations.publicIp)  ? [
      {
        name: appGatewayFrontendConfigurations.publicIp.name
        properties: {
          publicIPAddress: {
            id: azPublicIpAddressNameResource.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontendConfigurations.privateIp) ? [
      {
        name: appGatewayFrontendConfigurations.privateIp.name
        properties: {
          subnet: {
            id: azVirtualNetworkSubnetResource.id
          }
        }
      }
    ] : [ ])))
    frontendPorts: frontenPorts
    httpListeners: frontendHttpListeners
    backendAddressPools: backendAddressPools
    backendHttpSettingsCollection: backendPorts
    requestRoutingRules: routingRules
  }
}

