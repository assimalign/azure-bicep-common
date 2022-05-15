@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('')
param publicDnsZoneName string

@description('')
param publicDnsZoneARecords array







resource azPublicDnsZoneDeployment 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: publicDnsZoneName
  location: 'Global'
  properties: {
    zoneType: 'Public'
  }
}
