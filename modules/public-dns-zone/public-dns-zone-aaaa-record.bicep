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
param publicDnsZoneAaaaRecordName string

@description('')
param publicDnsZoneAaaaRecordValues array

@description('')
param publicDnsZoneAaaaRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZoneAaaaRecord 'Microsoft.Network/dnsZones/AAAA@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZoneAaaaRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZoneAaaaRecordTtl
    AAAARecords: [
      for value in publicDnsZoneAaaaRecordValues: {
        ipv6Address: value
      }
    ]
  }
}

output publicDnsZoneAaaaRecord object = publicDnsZoneAaaaRecord
