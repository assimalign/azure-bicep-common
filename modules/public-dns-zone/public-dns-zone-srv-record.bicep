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
param publicDnsZoneServiceRecordName string

@description('')
param publicDnsZoneServiceRecordValues array

@description('')
param publicDnsZoneServiceRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZoneServiceRecord 'Microsoft.Network/dnsZones/SRV@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZoneServiceRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZoneServiceRecordTtl
    SRVRecords: [
      for value in publicDnsZoneServiceRecordValues: {
        port: value.port
        priority: value.priority
        weight: value.weight
        target: formatName(value.target, affix, environment, region)
      }
    ]
  }
}

output publicDnsZoneServiceRecord object = publicDnsZoneServiceRecord
