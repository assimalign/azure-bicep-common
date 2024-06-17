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
param publicDnsZoneMailExchangerRecordName string

@description('')
param publicDnsZoneMailExchangerRecordValues array

@description('')
param publicDnsZoneMailExchangerRecordTtl int = 3600

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource publicDnsZoneMailExchangerRecord 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  name: '${formatName(publicDnsZoneName, affix, environment, region)}/${formatName(publicDnsZoneMailExchangerRecordName, affix, environment, region)}'
  properties: {
    TTL: publicDnsZoneMailExchangerRecordTtl
    MXRecords: [
      for value in publicDnsZoneMailExchangerRecordValues: {
        preference: value.preference
        exchange: formatName(value.exchange, affix, environment, region)
      }
    ]
  }
}

output publicDnsZoneMailExchangerRecord object = publicDnsZoneMailExchangerRecord
