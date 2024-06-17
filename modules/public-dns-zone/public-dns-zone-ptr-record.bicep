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
param publicDnsZonePointerRecordName string

@description('')
param publicDnsZonePointerRecordValues array

@description('')
param publicDnsZonePointerRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZonePointerRecord 'Microsoft.Network/dnsZones/PTR@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZonePointerRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZonePointerRecordTtl
    PTRRecords: [
      for value in publicDnsZonePointerRecordValues: {
        ptrdname: formatName(value, affix, environment, region)
      }
    ]
  }
}

output publicDnsZonePointerRecord object = publicDnsZonePointerRecord
