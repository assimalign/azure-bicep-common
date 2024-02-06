@description('The environment in which the resource(s) will be deployed.')
param environment string = ''

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

@description('')
param appGatewayConfigs object = {}

@description('The tags to attach to the resource when deployed')
param appGatewayTags object = {}

func format(name string, env string, region string) string => replace(replace(name, '@environment', env), '@region', region)

// 1. Get Virtual Network Subnet to reference for Ip Configurations
resource virtualNetworkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = {
  name: format('${appGatewayFrontend.privateIp.privateIpVirtualNetwork}/${appGatewayFrontend.privateIp.privateIpSubnet}', environment, region)
  scope: resourceGroup(format(appGatewayFrontend.privateIp.privateIpResourceGroup, environment, region))
}

// 2. Get a Public IP address for the frontend of the gateway if applicable
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' existing = if (!empty(appGatewayFrontend.publicIp)) {
  name: format(appGatewayFrontend.publicIp.publicIpName, environment, region)
  scope: resourceGroup(format(appGatewayFrontend.publicIp.publicIpResourceGroup, environment, region))
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-06-01' = {
  name: format(appGatewayName, environment, region)
  location: appGatewayLocation
  properties: {
    sku: any(!empty(environment) && contains(appGatewaySku, environment) ? {
      name: '${appGatewaySku[environment].tier}_${appGatewaySku[environment].size}'
      tier: appGatewaySku[environment].tier
      capacity: appGatewaySku[environment].capacity

    } : {
      name: '${appGatewaySku.default.tier}_${appGatewaySku.default.size}'
      tier: appGatewaySku.default.tier
      capacity: appGatewaySku.default.capacity
    })
    gatewayIPConfigurations: [
      {
        name: format('${appGatewayName}-ip-configuration', environment, region)
        properties: {
          subnet: {
            id: virtualNetworkSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: any(!empty(appGatewayFrontend.publicIp) && !empty(appGatewayFrontend.privateIp) ? [
      {
        name: appGatewayFrontend.publicIp.name
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
      {
        name: appGatewayFrontend.privateIp.name
        properties: {
          subnet: {
            id: virtualNetworkSubnet.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontend.publicIp) ? [
      {
        name: appGatewayFrontend.publicIp.name
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ] : any(!empty(appGatewayFrontend.privateIp) ? [
      {
        name: appGatewayFrontend.privateIp.name
        properties: {
          subnet: {
            id: virtualNetworkSubnet.id
          }
        }
      }
    ] : [])))
    frontendPorts: [for port in appGatewayFrontend.ports: {
      name: port.name
      properties: {
        port: port.frontendPort
      }
    }]
    httpListeners: [for listener in appGatewayFrontend.listeners: {
      name: listener.name
      properties: {
        frontendIPConfiguration: {
          id: any('${resourceId('Microsoft.Network/applicationGateways', format(appGatewayName, environment, region))}/frontendIPConfigurations/${listener.frontendIp}')
        }
        frontendPort: {
          id: any('${resourceId('Microsoft.Network/applicationGateways', format(appGatewayName, environment, region))}/frontendPorts/${listener.frontendPort}')
        }
        protocol: listener.frontendProtocol
        sslCertificate: null
      }
    }]
    backendAddressPools: [for pool in appGatewayBackend.receivers: {
      name: pool.name
      properties: {
        backendAddresses: !empty(environment) && contains(appGatewaySku, environment) ? pool.addresses[environment] : pool.addresses.default
      }
    }]
    backendHttpSettingsCollection: [for port in appGatewayBackend.ports: {
      name: port.name
      properties: {
        cookieBasedAffinity: 'Disabled'
        port: port.backendPort
        protocol: port.backendProtocol
        requestTimeout: port.backendRequestTimeout
      }
    }]
    requestRoutingRules: [for rule in appGatewayRoutingRules: {
      name: rule.name
      properties: {
        ruleType: rule.routeType
        httpListener: {
          id: any('${resourceId('Microsoft.Network/applicationGateways', format(appGatewayName, environment, region))}/httpListeners/${rule.routeFromHttpListener}')
        }
        backendAddressPool: {
          id: any('${resourceId('Microsoft.Network/applicationGateways', format(appGatewayName, environment, region))}/backendAddressPools/${rule.routeToBackendPool}')
        }
        backendHttpSettings: {
          id: any('${resourceId('Microsoft.Network/applicationGateways', format(appGatewayName, environment, region))}/backendHttpSettingsCollection/${rule.routeToBackendPort}')
        }
      }
    }]
    enableHttp2: contains(appGatewayConfigs, 'appGatewayHttp2Enabled') ? appGatewayConfigs.appGatewayHttp2Enabled : false
  }
  tags: union(appGatewayTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output appGateway object = appGateway
