@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Private DNS Zone')
param privateDnsZoneName string

@description('The name of the record to add to the ')
param privateDnsZoneRecordName string

@description('The time to live for the record')
param privateDnsZoneTtl int = 3600

@description('A list of records to add to the private DNS Zone')
param privateDnsZoneRecords array



// 1.1 Set A Records if any in Private DNS Zone
resource azPrivateDnsARecordsDeployment 'Microsoft.Network/privateDnsZones/TXT@2020-06-01' = {
  name: '${privateDnsZoneName}/${privateDnsZoneRecordName}'
  properties: {
   ttl: privateDnsZoneTtl
   txtRecords: privateDnsZoneRecords
  }
}
