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

@description('The name of the Private DNS Zone')
param privateDnsZoneName string

@description('The name of the record to add to the ')
param privateDnsZoneRecordName string

@description('The time to live for the record')
param privateDnsZoneTtl int = 3600

@description('A list of records to add to the private DNS Zone')
param privateDnsZoneRecord string


resource azPrivateDnsARecordsDeployment 'Microsoft.Network/privateDnsZones/CNAME@2020-06-01' = {
  name: replace(replace('${privateDnsZoneName}/${privateDnsZoneRecordName}', '@environment', environment) , '@region', region)
  properties: {
   ttl: privateDnsZoneTtl
   cnameRecord: {
     cname: privateDnsZoneRecord
   }
  }
}
