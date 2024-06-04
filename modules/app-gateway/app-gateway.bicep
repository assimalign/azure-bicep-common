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
@description('The environment in which the resource(s) will be deployed.')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the Azure App Gateway.')
param appGatewayName string

@description('The location/region the Azure App Gateway will be deployed to.')
param appGatewayLocation string = resourceGroup().location

@description('The pricing tier of the Azure App Gateway.')
param appGatewaySku object

@description('The app gateway backend configuration.')
param appGatewayBackend object

@description('The app gateway frontend configuration.')
param appGatewayFrontend object

@description('The Azure App Gateway routing rules. Reference Link: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-request-routing-rules')
param appGatewayRoutingRules array

@description('')
param appGatewayConfigs object = {}

@description('The tags to attach to the resource when deployed')
param appGatewayTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get Virtual Network Subnet to reference for Ip Configurations
resource virtualNetworkSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: formatName(
    '${appGatewayFrontend.privateIp.privateIpVirtualNetwork}/${appGatewayFrontend.privateIp.privateIpSubnet}',
    affix,
    environment,
    region
  )
  scope: resourceGroup(formatName(appGatewayFrontend.privateIp.privateIpResourceGroup, affix, environment, region))
}

// 2. Get a Public IP address for the frontend of the gateway if applicable
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = if (contains(
  appGatewayFrontend,
  'frontendPublicIp'
)) {
  name: formatName(appGatewayFrontend.frontendPublicIp.publicIpName, affix, environment, region)
  scope: resourceGroup(formatName(appGatewayFrontend.frontendPublicIp.publicIpResourceGroup, affix, environment, region))
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: formatName(appGatewayName, affix, environment, region)
  location: appGatewayLocation
  properties: {
    sku: any(!empty(environment) && contains(appGatewaySku, environment)
      ? {
          name: '${appGatewaySku[environment].tier}_${appGatewaySku[environment].size}'
          tier: appGatewaySku[environment].tier
          capacity: appGatewaySku[environment].capacity
        }
      : {
          name: '${appGatewaySku.default.tier}_${appGatewaySku.default.size}'
          tier: appGatewaySku.default.tier
          capacity: appGatewaySku.default.capacity
        })
    gatewayIPConfigurations: [
      {
        name: formatName('${appGatewayName}-ip-configuration', affix, environment, region)
        properties: {
          subnet: {
            id: virtualNetworkSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: any(!empty(appGatewayFrontend.publicIp) && !empty(appGatewayFrontend.privateIp)
      ? [
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
        ]
      : any(!empty(appGatewayFrontend.publicIp)
          ? [
              {
                name: appGatewayFrontend.publicIp.name
                properties: {
                  publicIPAddress: {
                    id: publicIpAddress.id
                  }
                }
              }
            ]
          : any(!empty(appGatewayFrontend.privateIp)
              ? [
                  {
                    name: appGatewayFrontend.privateIp.name
                    properties: {
                      subnet: {
                        id: virtualNetworkSubnet.id
                      }
                    }
                  }
                ]
              : [])))
    frontendPorts: [
      for port in appGatewayFrontend.ports: {
        name: port.frontendName
        properties: {
          port: port.frontendPort
        }
      }
    ]
    httpListeners: [
      for listener in appGatewayFrontend.listeners: {
        name: listener.name
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendIPConfigurations',
              formatName(appGatewayName, affix, environment, region),
              listener.frontendIp
            )
          }
          frontendPort: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendPorts',
              formatName(appGatewayName, affix, environment, region),
              listener.frontendPort
            )
          }
          protocol: listener.frontendProtocol
          sslCertificate: null
        }
      }
    ]
    backendAddressPools: [
      for pool in appGatewayBackend.receivers: {
        name: pool.name
        properties: {
          backendAddresses: !empty(environment) && contains(appGatewaySku, environment)
            ? pool.addresses[environment]
            : pool.addresses.default
        }
      }
    ]
    backendHttpSettingsCollection: [
      for port in appGatewayBackend.ports: {
        name: port.name
        properties: {
          cookieBasedAffinity: 'Disabled'
          port: port.backendPort
          protocol: port.backendProtocol
          requestTimeout: port.backendRequestTimeout
        }
      }
    ]
    requestRoutingRules: [
      for rule in appGatewayRoutingRules: {
        name: rule.name
        properties: {
          ruleType: rule.routeType
          httpListener: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/httpListeners',
              formatName(appGatewayName, affix, environment, region),
              rule.routeFromHttpListener
            )
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendAddressPools',
              formatName(appGatewayName, affix, environment, region),
              rule.routeToBackendPool
            )
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              formatName(appGatewayName, affix, environment, region),
              rule.routeToBackendPort
            )
          }
        }
      }
    ]
    enableHttp2: contains(appGatewayConfigs, 'appGatewayHttp2Enabled')
      ? appGatewayConfigs.appGatewayHttp2Enabled
      : false
  }
  tags: union(appGatewayTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output appGateway object = appGateway
