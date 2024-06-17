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
param publicDnsZoneAliasRecords array = []

@description('')
param publicDnsZoneAaaaaRecords array = []

@description('')
param publicDnsZoneServiceRecords array = []

@description('')
param publicDnsZonePointerRecords array = []

@description('')
param publicDnsZoneTextRecords array = []

@description('')
param publicDnsZoneCanonicalNameRecords array = []

@description('')
param publicDnsZoneNameServerRecords array = []

@description('')
param publicDnsZoneMailExchangerRecords array = []

@description('')
param publicDnsZoneTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

func formatId(name string, affix string, environment string, region string) string =>
  guid(replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region))

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: replace(replace(replace(publicDnsZoneName, '@affix', affix), '@environment', environment), '@region', region)
  location: 'Global'
  properties: {
    zoneType: 'Public'
  }
  tags: union(publicDnsZoneTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

module aliasRecords 'public-dns-zone-a-record.bicep' = [
  for record in publicDnsZoneAliasRecords: {
    name: 'dns-zone-a-${formatId('${publicDnsZoneName}/${record.publicDnsZoneAliasRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneAliasRecordName: record.publicDnsZoneAliasRecordName
      publicDnsZoneAliasRecordValues: record.publicDnsZoneAliasRecordValues
      publicDnsZoneAliasRecordTtl: record.?publicDnsZoneAliasRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module aaaaRecords 'public-dns-zone-aaaa-record.bicep' = [
  for record in publicDnsZoneAaaaaRecords: {
    name: 'dns-zone-aaaa-${formatId('${publicDnsZoneName}/${record.publicDnsZoneAaaaRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneAaaaRecordName: record.publicDnsZoneAaaaRecordName
      publicDnsZoneAaaaRecordValues: record.publicDnsZoneAaaaRecordValues
      publicDnsZoneAaaaRecordTtl: record.?publicDnsZoneAaaaRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module nameServerRecords 'public-dns-zone-ns-record.bicep' = [
  for record in publicDnsZoneNameServerRecords: {
    name: 'dns-zone-ns-${formatId('${publicDnsZoneName}/${record.dnsZoneNameServerRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneNameServerRecordName: record.publicDnsZoneNameServerRecordName
      publicDnsZoneNameServerRecordValues: record.publicDnsZoneNameServerRecordValues
      publicDnsZoneNameServerRecordTtl: record.?publicDnsZoneNameServerRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module textRecords 'public-dns-zone-txt-record.bicep' = [
  for record in publicDnsZoneTextRecords: {
    name: 'dns-zone-txt-${formatId('${publicDnsZoneName}/${record.dnsZoneTextRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneTextRecordName: record.publicDnsZoneTextRecordName
      publicDnsZoneTextRecordValues: record.publicDnsZoneTextRecordValues
      publicDnsZoneTextRecordTtl: record.?publicDnsZoneTextRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module mailExchangerRecords 'public-dns-zone-mx-record.bicep' = [
  for record in publicDnsZoneMailExchangerRecords: {
    name: 'dns-zone-mx-${formatId('${publicDnsZoneName}/${record.dnsZoneMailExchangerRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneMailExchangerRecordName: record.publicDnsZoneMailExchangerRecordName
      publicDnsZoneMailExchangerRecordValues: record.publicDnsZoneMailExchangerRecordValues
      publicDnsZoneMailExchangerRecordTtl: record.?publicDnsZoneMailExchangerRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module canonicalNameRecords 'public-dns-zone-cname-record.bicep' = [
  for record in publicDnsZoneCanonicalNameRecords: {
    name: 'dns-zone-cname-${formatId('${publicDnsZoneName}/${record.publicDnsZoneCanonicalNameRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneCanonicalNameRecordName: record.publicDnsZoneCanonicalNameRecordName
      publicDnsZoneCanonicalNameRecordValue: record.publicDnsZoneCanonicalNameRecordValue
      publicDnsZoneCanonicalNameRecordTtl: record.?dnsZoneCanonicalNameRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module pointerRecords 'public-dns-zone-ptr-record.bicep' = [
  for record in publicDnsZonePointerRecords: {
    name: 'dns-zone-ptr-${formatId('${publicDnsZoneName}/${record.dnsZonePointerRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZonePointerRecordName: record.publicDnsZonePointerRecordName
      publicDnsZonePointerRecordValues: record.publicDnsZonePointerRecordValues
      publicDnsZonePointerRecordTtl: record.?publicDnsZonePointerRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

module serviceRecords 'public-dns-zone-srv-record.bicep' = [
  for record in publicDnsZoneServiceRecords: {
    name: 'dns-zone-srv-${formatId('${publicDnsZoneName}/${record.dnsZoneServiceRecordName}', affix, environment, region)}'
    params: {
      affix: affix
      region: region
      environment: environment
      publicDnsZoneName: publicDnsZoneName
      publicDnsZoneServiceRecordName: record.publicDnsZoneServiceRecordName
      publicDnsZoneServiceRecordValues: record.publicDnsZoneServiceRecordValues
      publicDnsZoneServiceRecordTtl: record.?publicDnsZoneServiceRecordTtl
    }
    dependsOn: [
      dnsZone
    ]
  }
]

output dnsZone object = dnsZone
