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

@description('')
param publicDnsZoneName string

@description('')
param publicDnsZoneAliasRecordName string

@description('')
param publicDnsZoneAliasRecordValues array

@description('')
param publicDnsZoneAliasRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZoneAliasRecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZoneAliasRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZoneAliasRecordTtl
    ARecords: [
      for value in publicDnsZoneAliasRecordValues: {
        ipv4Address: value
      }
    ]
  }
}

output publicDnsZoneAliasRecord object = publicDnsZoneAliasRecord
