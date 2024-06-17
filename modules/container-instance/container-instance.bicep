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
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the Azure Cognitive Search Service to be deployed.')
param containerInstanceName string

@description('')
param containerInstanceLocation string = resourceGroup().location

@description('')
param containerInstanceZones array = []

@allowed([
  'Linux'
  'Windows'
])
@description('')
param containerInstanceOs string = 'Linux'

@description('')
param containerInstanceEnableMsi bool = false

@description('')
param containerInstanceVirtualNetworkConfig object = {}

@description('')
param containerInstanceImageConfig object

@description('')
param containerInstanceTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: formatName(containerInstanceName, affix, environment, region)
  location: containerInstanceLocation
  zones: containerInstanceZones
  identity: {
    type: containerInstanceEnableMsi ? 'SystemAssigned' : 'None'
  }
  properties: {
    osType: containerInstanceOs

    ipAddress: {
      ports: contains(containerInstanceVirtualNetworkConfig, 'virtualNetworkPorts')
        ? containerInstanceVirtualNetworkConfig.virtualNetworkPorts
        : [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
      type: empty(containerInstanceVirtualNetworkConfig) ? 'Public' : 'Private'
      ip: contains(containerInstanceVirtualNetworkConfig, 'virtualNetworkPrivateIp')
        ? contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp, affix)
            ? contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix], region)
                ? contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix][region], environment)
                    ? containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix][region][environment]
                    : containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix][region].default
                : contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix], environment)
                    ? containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix][environment]
                    : containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[affix].default
            : contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp, region)
                ? contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[region], environment)
                    ? containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[region][environment]
                    : containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[region].default
                : contains(containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp, environment)
                    ? containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp[environment]
                    : containerInstanceVirtualNetworkConfig.virtualNetworkPrivateIp.default
        : null
    }
    sku: 'Standard'
    subnetIds: empty(containerInstanceVirtualNetworkConfig)
      ? []
      : [
          {
            id: resourceId(
              formatName(containerInstanceVirtualNetworkConfig.virtualNetworkResourceGroup, affix, environment, region),
              'Microsoft.Network/virtualNetworks/subnets',
              formatName(containerInstanceVirtualNetworkConfig.virtualNetwork, affix, environment, region),
              formatName(containerInstanceVirtualNetworkConfig.virtualNetworkSubnet, affix, environment, region)
            )
          }
        ]
    containers: [
      {
        name: formatName(containerInstanceName, affix, environment, region)
        properties: {
          image: formatName(containerInstanceImageConfig.imageName, affix, environment, region)
          ports: contains(containerInstanceVirtualNetworkConfig, 'virtualNetworkPorts')
            ? containerInstanceVirtualNetworkConfig.virtualNetworkPorts
            : [
                {
                  port: 80
                  protocol: 'TCP'
                }
              ]
          resources: {
            requests: contains(containerInstanceImageConfig.imageSize, environment)
              ? {
                  cpu: containerInstanceImageConfig.imageSize[environment].cpuCount
                  memoryInGB: containerInstanceImageConfig.imageSize[environment].memory
                }
              : {
                  cpu: containerInstanceImageConfig.imageSize.default.cpuCount
                  memoryInGB: containerInstanceImageConfig.imageSize.default.memory
                }
          }
        }
      }
    ]
  }
  tags: union(containerInstanceTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
