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

@minLength(1)
@description('')
param privateEndpointDnsZoneGroups array

@description('')
param privateEndpointTags object = {}

func formatName(name string, environment string, region string) string =>
  replace(replace(name, '@environment', environment), '@region', region)

// 1. Get Existing Subnet Resource within a virtual network
resource virtualNetwork 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: replace(replace('${privateEndpointVirtualNetworkName}/${privateEndpointVirtualNetworkSubnetName}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(privateEndpointVirtualNetworkResourceGroup, '@environment', environment), '@region', region))
}
// 3. Deploy the private endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: replace(replace(privateEndpointName, '@environment', environment), '@region', region)
  location: privateEndpointLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: replace(replace(privateEndpointName, '@environment', environment), '@region', region)
        properties: {
          privateLinkServiceId: any(replace(replace(replace(privateEndpointResourceIdLink, '@environment', environment), '@region', region), '@subscription', subscription().subscriptionId))
          groupIds: privateEndpointGroupIds
        }
      }
    ]
    subnet: {
      id: virtualNetwork.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]
  resource dnsZoneGroups 'privateDnsZoneGroups' = [for zone in privateEndpointDnsZoneGroups: {
    name: formatName(zone.privateDnsZoneName, environment, region)
    properties: {
      privateDnsZoneConfigs: [for zone in privateEndpointDnsZoneGroups: {
          name: zone.privateDnsZoneGroup
          properties: {
            privateDnsZoneId: resourceId(
              formatName(zone.privateDnsZoneName, environment, region),
              'Microsoft.Network/privateDnsZones',
              formatName(zone.privateDnsZoneResourceGroup, environment, region)
            )
          }
        }
      ]
    }
  }]
  tags: union(privateEndpointTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

// 4. Return Deployment ouput
output privateEndpoint object = privateEndpoint
