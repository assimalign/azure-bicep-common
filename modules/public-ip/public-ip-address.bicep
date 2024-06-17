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

@description('The name of the Public IP Address')
param publicIpName string

@description('')
param publicIpLocation string = resourceGroup().location

@description('The pricing tier of the Public IP Address')
param publicIpSku object

@allowed([
  'Dynamic'
  'Static'
])
@description('The allocation method of the Public IP Address')
param publicIpAllocationMethod string = 'Dynamic'

@description('')
param publicIpConfigs object = {}

@description('')
param publicIpDnsZoneAliasRecords array = []

@description('')
param publicIpTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy Public Ip Address
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: formatName(publicIpName, affix, environment, region)
  location: publicIpLocation
  zones: publicIpConfigs.?zones ?? []
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod
    dnsSettings: !contains(publicIpConfigs, 'dnsNameLabel')
      ? null
      : {
          domainNameLabel: formatName(publicIpConfigs.dnsNameLabel, affix, environment, region)
        }
  }
  sku: {
    name: contains(publicIpSku, environment) ? publicIpSku[environment].name : publicIpSku.default.name
    tier: contains(publicIpSku, environment) ? publicIpSku[environment].tier : publicIpSku.default.tier
  }
  tags: union(publicIpTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

module dnsZoneAliases '../public-dns-zone/public-dns-zone-a-record.bicep' = [for alias in publicIpDnsZoneAliasRecords: {
  name: 'pip-dns-alias-${guid(formatName('${alias.publicDnsZoneName}/${alias.publicDnsZoneAliasRecordName}', affix, environment, region))}'
  scope: resourceGroup(formatName(alias.publicDnsZoneResourceGroup, affix, environment, region)) 
  params: {
    affix: affix
    region: region
    environment: environment
    publicDnsZoneName: alias.publicDnsZoneName
    publicDnsZoneAliasRecordName: alias.publicDnsZoneAliasRecordName
    publicDnsZoneAliasRecordValues: [
      publicIpAddress.properties.ipAddress
    ]
    publicDnsZoneAliasRecordTtl: alias.?publicDnsZoneAliasRecordTtl
  }
}]

output publicIpAddress object = publicIpAddress
