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

@description('The name of the private endpoint to be deployed')
param privateEndpointName string

@description('The location/region the Azure Private Enpoint will be deployed to.')
param privateEndpointLocation string = resourceGroup().location

@allowed([
  'amlworkspace'
  'account'
  'Bot'
  'Token'
  'Sql'
  'SqlOnDemand'
  'Dev'
  'Web'
  'namespace'
  'dataFactory'
  'portal'
  'cluster'
  'tenant'
  'databricks_ui_api'
  'browser_authentication'
  'batchAccount'
  'nodeManagement'
  'global'
  'feed'
  'connection'
  'management'
  'registry'
  'sqlServer'
  'managedInstance'
  'MongoDB'
  'Cassandra'
  'Gremlin'
  'Table'
  'Analytical'
  'coordinator'
  'postgresqlServer'
  'mysqlServer'
  'mariadbServer'
  'redisCache'
  'redisEnterprise'
  'hybridcompute'
  'iotHub'
  'iotDps'
  'DeviceUpdate'
  'iotApp'
  'API'
  'topic'
  'domain'
  'partnernamespace'
  'gateway'
  'healthcareworkspace'
  'keydelivery'
  'liveevent'
  'streamingendpoint'
  'Webhook'
  'DSCAndHybridWorker'
  'AzureBackup'
  'AzureSiteRecovery'
  'azuremonitor'
  'Default'
  'ResourceManagement'
  'grafana'
  'vault'
  'managedhsm'
  'configurationStores'
  'standard'
  'blob'
  'blob_secondary'
  'table_secondary'
  'queue'
  'queue_secondary'
  'file'
  'web_secondary'
  'dfs'
  'dfs_secondary'
  'afs'
  'disks'
  'searchService'
  'sites'
  'signalr'
  'staticSites'
])
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

@description('')
param privateEndpointDnsZoneGroupConfigs object

@description('')
param privateEndpointTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get Existing Subnet Resource within a virtual network
resource virtualNetwork 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: formatName(
    '${privateEndpointVirtualNetworkName}/${privateEndpointVirtualNetworkSubnetName}',
    affix,
    environment,
    region
  )
  scope: resourceGroup(formatName(privateEndpointVirtualNetworkResourceGroup, affix, environment, region))
}

// 3. Deploy the private endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: formatName(privateEndpointName, affix, environment, region)
  location: privateEndpointLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: formatName(privateEndpointName, affix, environment, region)
        properties: {
          privateLinkServiceId: any(replace(
            formatName(privateEndpointResourceIdLink, affix, environment, region),
            '@subscription',
            subscription().subscriptionId
          ))
          groupIds: privateEndpointGroupIds
        }
      }
    ]
    subnet: {
      id: virtualNetwork.id
    }
  }
  resource dnsZoneGroups 'privateDnsZoneGroups' = {
    name: formatName(privateEndpointDnsZoneGroupConfigs.privateDnsZoneGroupName, affix, environment, region)
    properties: {
      privateDnsZoneConfigs: [
        for zone in privateEndpointDnsZoneGroupConfigs.privateDnsZones: {
          name: replace(zone.privateDnsZone, '.', '-')
          properties: {
            privateDnsZoneId: resourceId(
              formatName(zone.privateDnsZoneResourceGroup, affix, environment, region),
              'Microsoft.Network/privateDnsZones',
              formatName(zone.privateDnsZone, affix, environment, region)
            )
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
output privateEndpoint object = privateEndpoint
