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
param publicDnsZoneCanonicalNameRecordName string

@description('')
param publicDnsZoneCanonicalNameRecordValue string

@description('')
param publicDnsZoneCanonicalNameRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZoneCanonicalNameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZoneCanonicalNameRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZoneCanonicalNameRecordTtl
    CNAMERecord: {
      cname: formatName(publicDnsZoneCanonicalNameRecordValue, affix, environment, region)
    }
  }
}

output publicDnsZoneCanonicalNameRecord object = publicDnsZoneCanonicalNameRecord
