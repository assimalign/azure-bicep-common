@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('')
param publicDnsZoneName string

@description('')
param publicDnsZoneTags object = {}


resource azPublicDnsZoneDeployment 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: publicDnsZoneName
  location: 'Global'
  properties: {
    zoneType: 'Public'
  }
  tags: union(publicDnsZoneTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
