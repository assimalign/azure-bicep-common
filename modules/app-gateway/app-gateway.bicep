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

@description('')
param appGatewayZones array

@description('')
param appGatewayVirtualNetworkConfig object

@description('')
param appGatewayBackendSettings array

@description('')
param appGatewayBackendPools array

@description('The app gateway frontend configuration.')
param appGatewayFrontend object

@description('The Azure App Gateway routing rules. Reference Link: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-request-routing-rules')
param appGatewayRoutingRules array

@description('')
param appGatewayCertificates array = []

@description('')
param appGatewayConfig object = {}

@description('The tags to attach to the resource when deployed')
param appGatewayTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource staticSites 'Microsoft.Web/staticSites@2023-12-01' existing = [
  for (pool, index) in appGatewayBackendPools: if (contains(pool, 'staticSiteName')) {
    name: formatName(pool.?staticSiteName ?? 'no-static-site-${index}', affix, environment, region)
    scope: resourceGroup(formatName(
      pool.?staticSiteResourceGroup ?? 'no-static-site-${index}',
      affix,
      environment,
      region
    ))
  }
]

resource appServices 'Microsoft.Web/sites@2023-12-01' existing = [
  for (pool, index) in appGatewayBackendPools: if (contains(pool, 'appServiceName')) {
    name: formatName(pool.?appServiceName ?? 'no-web-site-${index}', affix, environment, region)
    scope: resourceGroup(formatName(pool.?appServiceResourceGroup ?? 'no-web-site-${index}', affix, environment, region))
  }
]

resource appGateway 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region)
  location: appGatewayLocation
  zones: appGatewayZones
  properties: {
    sku: contains(appGatewaySku, environment)
      ? {
          name: appGatewaySku[environment].tier
          tier: appGatewaySku[environment].tier
        }
      : {
          name: appGatewaySku.default.tier
          tier: appGatewaySku.default.tier
        }
    gatewayIPConfigurations: [
      {
        name: replace(
          replace(replace('${appGatewayName}-ip-config', '@affix', affix), '@environment', environment),
          '@region',
          region
        )
        properties: {
          subnet: {
            id: resourceId(
              replace(
                replace(
                  replace(appGatewayVirtualNetworkConfig.virtualNetworkResourceGroup, '@affix', affix),
                  '@environment',
                  environment
                ),
                '@region',
                region
              ),
              'Microsoft.Network/virtualNetworks/subnets',
              replace(
                replace(
                  replace(appGatewayVirtualNetworkConfig.virtualNetwork, '@affix', affix),
                  '@environment',
                  environment
                ),
                '@region',
                region
              ),
              replace(
                replace(
                  replace(appGatewayVirtualNetworkConfig.virtualNetworkSubnet, '@affix', affix),
                  '@environment',
                  environment
                ),
                '@region',
                region
              )
            )
          }
        }
      }
    ]
    frontendIPConfigurations: contains(appGatewayFrontend, 'frontendPublicIp') && contains(
        appGatewayFrontend,
        'frontendPrivateIp'
      )
      ? [
          {
            name: replace(
              replace(replace('${appGatewayName}-public-ip-config', '@affix', affix), '@environment', environment),
              '@region',
              region
            )
            properties: {
              publicIPAddress: {
                id: resourceId(
                  replace(
                    replace(
                      replace(appGatewayFrontend.frontendPublicIp.publicIpResourceGroup, '@affix', affix),
                      '@environment',
                      environment
                    ),
                    '@region',
                    region
                  ),
                  'Microsoft.Network/publicIPAddresses',
                  replace(
                    replace(
                      replace(appGatewayFrontend.frontendPublicIp.publicIpName, '@affix', affix),
                      '@environment',
                      environment
                    ),
                    '@region',
                    region
                  )
                )
              }
            }
          }
          {
            name: replace(
              replace(replace('${appGatewayName}-private-ip-config', '@affix', affix), '@environment', environment),
              '@region',
              region
            )
            properties: {
              privateIPAddress: appGatewayFrontend.frontendPrivateIp
              privateIPAllocationMethod: 'Dynamic'
              subnet: {
                id: resourceId(
                  replace(
                    replace(
                      replace(appGatewayVirtualNetworkConfig.virtualNetworkResourceGroup, '@affix', affix),
                      '@environment',
                      environment
                    ),
                    '@region',
                    region
                  ),
                  'Microsoft.Network/virtualNetworks/subnets',
                  replace(
                    replace(
                      replace(appGatewayVirtualNetworkConfig.virtualNetwork, '@affix', affix),
                      '@environment',
                      environment
                    ),
                    '@region',
                    region
                  ),
                  replace(
                    replace(
                      replace(appGatewayVirtualNetworkConfig.virtualNetworkSubnet, '@affix', affix),
                      '@environment',
                      environment
                    ),
                    '@region',
                    region
                  )
                )
              }
            }
          }
        ]
      : contains(appGatewayFrontend, 'frontendPublicIp')
          ? [
              {
                name: replace(
                  replace(replace('${appGatewayName}-public-ip-config', '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
                properties: {
                  publicIPAddress: {
                    id: resourceId(
                      replace(
                        replace(
                          replace(appGatewayFrontend.frontendPublicIp.publicIpResourceGroup, '@affix', affix),
                          '@environment',
                          environment
                        ),
                        '@region',
                        region
                      ),
                      'Microsoft.Network/publicIPAddresses',
                      replace(
                        replace(
                          replace(appGatewayFrontend.frontendPublicIp.publicIpName, '@affix', affix),
                          '@environment',
                          environment
                        ),
                        '@region',
                        region
                      )
                    )
                  }
                }
              }
            ]
          : contains(appGatewayFrontend, 'frontendPrivateIp')
              ? [
                  {
                    name: replace(
                      replace(
                        replace('${appGatewayName}-private-ip-config', '@affix', affix),
                        '@environment',
                        environment
                      ),
                      '@region',
                      region
                    )
                    properties: {
                      privateIPAddress: appGatewayFrontend.frontendPrivateIp
                      privateIPAllocationMethod: 'Static'
                      subnet: {
                        id: resourceId(
                          replace(
                            replace(
                              replace(appGatewayVirtualNetworkConfig.virtualNetworkResourceGroup, '@affix', affix),
                              '@environment',
                              environment
                            ),
                            '@region',
                            region
                          ),
                          'Microsoft.Network/virtualNetworks/subnets',
                          replace(
                            replace(
                              replace(appGatewayVirtualNetworkConfig.virtualNetwork, '@affix', affix),
                              '@environment',
                              environment
                            ),
                            '@region',
                            region
                          ),
                          replace(
                            replace(
                              replace(appGatewayVirtualNetworkConfig.virtualNetworkSubnet, '@affix', affix),
                              '@environment',
                              environment
                            ),
                            '@region',
                            region
                          )
                        )
                      }
                    }
                  }
                ]
              : []
    frontendPorts: [
      for port in appGatewayFrontend.frontendPorts: {
        name: replace(replace(replace(port.portName, '@affix', affix), '@environment', environment), '@region', region)
        properties: {
          port: port.portNumber
        }
      }
    ]
    sslCertificates: [
      for cert in appGatewayCertificates: {
        name: replace(
          replace(replace(cert.certificateName, '@affix', affix), '@environment', environment),
          '@region',
          region
        )
        properties: {
          data: cert.certificateContent
          password: cert.certificatePassword
        }
      }
    ]
    httpListeners: [
      for listener in appGatewayFrontend.frontendListeners: {
        name: replace(
          replace(replace(listener.listenerName, '@affix', affix), '@environment', environment),
          '@region',
          region
        )
        properties: {
          hostName: contains(listener, 'listenerHostName')
            ? replace(
                replace(
                  replace(
                    replace(
                      contains(listener.listenerHostName, environment)
                        ? listener.listenerHostName[environment]
                        : listener.listenerHostName.default,
                      '@affix',
                      affix
                    ),
                    '@environment',
                    environment
                  ),
                  '@region',
                  region
                ),
                '..',
                '.'
              )
            : null
          hostNames: contains(listener, 'listenerHostNames')
            ? map(
                contains(listener.listenerHostNames, environment)
                  ? listener.listenerHostNames[environment]
                  : listener.listenerHostNames.default,
                host =>
                  replace(
                    replace(replace(replace(host, '@affix', affix), '@environment', environment), '@region', region),
                    '..',
                    '.'
                  )
              )
            : []
          protocol: listener.listenerProtocol
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendIPConfigurations',
              replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region),
              '${replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region)}-${listener.listenerUse == 'PublicIP' ? 'public-ip-config' : 'private-ip-config'}'
            )
          }
          frontendPort: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendPorts',
              replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region),
              replace(
                replace(replace(listener.listenerPortName, '@affix', affix), '@environment', environment),
                '@region',
                region
              )
            )
          }
          sslCertificate: contains(listener, 'listenerCertificateName')
            ? {
                id: resourceId(
                  'Microsoft.Network/applicationGateways/sslCertificates',
                  replace(
                    replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                    '@region',
                    region
                  ),
                  replace(
                    replace(replace(listener.listenerCertificateName, '@affix', affix), '@environment', environment),
                    '@region',
                    region
                  )
                )
              }
            : null
        }
      }
    ]
    probes: map(filter(appGatewayBackendSettings, setting => contains(setting, 'settingsProbe')), settings => {
      name: '${replace(replace(replace(settings.settingsName, '@affix', affix), '@environment', environment), '@region',region)}-probe'
      properties: {
        path: settings.settingsProbe.probePath
        pickHostNameFromBackendHttpSettings: true
        protocol: settings.settingsProbe.probeProtocol
        interval: settings.settingsProbe.?probeInterval ?? 30
        timeout: 30
        unhealthyThreshold: settings.settingsProbe.?probeRetryCount ?? 3
        minServers: 0
      }
    })
    backendAddressPools: [
      for (pool, index) in appGatewayBackendPools: {
        name: replace(replace(replace(pool.poolName, '@affix', affix), '@environment', environment), '@region', region)
        properties: {
          backendAddresses: contains(pool, 'staticSiteName')
            ? [
                {
                  fqdn: staticSites[index].properties.defaultHostname
                }
              ]
            : contains(pool, 'appServiceName')
                ? [
                    {
                      fqdn: appServices[index].properties.defaultHostName
                    }
                  ]
                : map(
                    pool.poolTargets,
                    target =>
                      contains(target, 'fqdn')
                        ? {
                            fqdn: replace(
                              replace(replace(target.fqdn, '@affix', affix), '@environment', environment),
                              '@region',
                              region
                            )
                          }
                        : {
                            ipAddress: target.ipAddress
                          }
                  )
        }
      }
    ]
    backendHttpSettingsCollection: [
      for setting in appGatewayBackendSettings: {
        name: replace(
          replace(replace(setting.settingsName, '@affix', affix), '@environment', environment),
          '@region',
          region
        )
        properties: {
          cookieBasedAffinity: 'Disabled'
          port: setting.settingsPort
          protocol: setting.settingsProtocol
          requestTimeout: 20
          path: setting.?settingsOverridePath ?? null
          pickHostNameFromBackendAddress: setting.?settingsUseHostNameFromBackendAddress
          hostName: setting.?settingsHostName ?? null
          probe: contains(setting, 'settingsProbe')
            ? {
                id: resourceId(
                  'Microsoft.Network/applicationGateways/probes',
                  replace(
                    replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                    '@region',
                    region
                  ),
                  '${replace(replace(replace(setting.settingsName, '@affix', affix), '@environment', environment), '@region',region)}-probe'
                )
              }
            : null
        }
      }
    ]
    urlPathMaps: map(filter(appGatewayRoutingRules, rule => contains(rule, 'routingRuleUriPathMaps')), rule => {
      name: replace(
        replace(replace(rule.routingRuleName, '@affix', affix), '@environment', environment),
        '@region',
        region
      )
      properties: {
        pathRules: map(rule.routingRuleUriPathMaps, path => {
          name: replace(
            replace(replace(path.routingRuleBackendPoolName, '@affix', affix), '@environment', environment),
            '@region',
            region
          )
          properties: {
            paths: path.routingRuleUriPaths
            backendAddressPool: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/backendAddressPools',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(path.routingRuleBackendPoolName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
            backendHttpSettings: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(path.routingRuleBackendSettingsName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
          }
        })
        defaultBackendAddressPool: {
          id: resourceId(
            'Microsoft.Network/applicationGateways/backendAddressPools',
            replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region),
            replace(
              replace(
                replace(rule.routingRuleUriPathMaps[0].routingRuleBackendPoolName, '@affix', affix),
                '@environment',
                environment
              ),
              '@region',
              region
            )
          )
        }
        defaultBackendHttpSettings: {
          id: resourceId(
            'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
            replace(replace(replace(appGatewayName, '@affix', affix), '@environment', environment), '@region', region),
            replace(
              replace(
                replace(rule.routingRuleUriPathMaps[0].routingRuleBackendSettingsName, '@affix', affix),
                '@environment',
                environment
              ),
              '@region',
              region
            )
          )
        }
      }
    })
    requestRoutingRules: map(appGatewayRoutingRules, (rule, index) => {
      name: replace(
        replace(replace(rule.routingRuleName, '@affix', affix), '@environment', environment),
        '@region',
        region
      )
      properties: contains(rule, 'routingRuleUriPathMaps')
        ? {
            ruleType: 'PathBasedRouting'
            priority: (index + 1) * 100
            urlPathMap: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/urlPathMaps',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(rule.routingRuleName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
            httpListener: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/httpListeners',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(rule.routingRuleFrontendListenerName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
          }
        : {
            ruleType: 'Basic'
            priority: (index + 1) * 100
            httpListener: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/httpListeners',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(rule.routingRuleFrontendListenerName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
            backendAddressPool: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/backendAddressPools',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(rule.routingRuleBackendPoolName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
            backendHttpSettings: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
                replace(
                  replace(replace(appGatewayName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                ),
                replace(
                  replace(replace(rule.routingRuleBackendSettingsName, '@affix', affix), '@environment', environment),
                  '@region',
                  region
                )
              )
            }
          }
    })
    enableHttp2: appGatewayConfig.?enableHttp2 ?? false
    autoscaleConfiguration: {
      minCapacity: contains(appGatewaySku, environment)
        ? appGatewaySku[environment].capacity
        : appGatewaySku.default.capacity
      maxCapacity: appGatewayConfig.?autoScaleMaxCapacity ?? 10
    }
  }

  tags: union(appGatewayTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output appGateway object = appGateway
