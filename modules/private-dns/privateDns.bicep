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

@description('The name of the Private DNS Zone')
param privateDnsZoneName string

@description('A list of network links to join to the Private DNS Zone')
param privateDnsZoneNetworkLinks array = []

@description('A list of Alias records to append to the Private DNS Zone')
param privateDnsZoneARecords array = []

@description('A list of Alias records to append to the Private DNS Zone')
param privateDnsZoneAaaaRecords array = []

@description('A list of CNAME records to append to the Private DNS Zone')
param privateDnsZoneCnameRecords array = []

@description('A list of Pointer records to append to the Private DNS Zone')
param privateDnsZonePtrRecords array = []

@description('A list of Mail Exchange records to append to the Private DNS Zone')
param privateDnsZoneMxRecords array = []

@description('A list of TXT records to append to the Private DNS Zone')
param privateDnsZoneTxtRecords array = []

@description('A list of SRV records to append to the Private DNS Zone')
param privateDnsZoneSrvRecords array = []

@description('')
param privtaeDnsZoneTags object = {}

// 1. Deploy Private DNS Zone scoped to the current Resource Group
resource azPrivateDnsDeployment 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: replace(replace(privateDnsZoneName, '@environment', environment), '@region', region)
  location: 'global'
  tags: union(privtaeDnsZoneTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 1.1 Set A Records if any in Private DNS Zone
module azPrivateDnsARecordsDeployment 'privateDnsARecord.bicep' = [for record in privateDnsZoneARecords: if (!empty(record)) {
  name: !empty(privateDnsZoneARecords) ? 'az-dns-private-a-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-a-0'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.ip4vAddresses
  }
}]

// 1.2 Set AAAA Records if any in Private DNS Zone
module azPrivateDnsAaaaRecordsDeployment 'privateDnsAaaaRecord.bicep' = [for record in privateDnsZoneAaaaRecords: if (!empty(record)) {
  name: !empty(privateDnsZoneAaaaRecords) ? 'az-dns-private-aaaa-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-aaaa-0'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.ip6vAddresses
  }
}]

// 1.3 Set MX Records if any in Private DNS Zone
module azPrivateDnsMxRecordsDeployment 'privateDnsMxRecord.bicep' = [for record in privateDnsZoneMxRecords: if (!empty(record)) {
  name: !empty(privateDnsZoneMxRecords) ? 'az-dns-private-mx-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-mx-0'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.exchanges
  }
}]

// 1.4 Set TXT Records if any in Private DNS Zone 
module azPrivateDnsTxtRecordsDeployment 'privateDnsTxtRecord.bicep' = [for record in privateDnsZoneTxtRecords: if (!empty(record)) {
  name: !empty(privateDnsZoneTxtRecords) ? 'az-dns-private-txt-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-txt'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.values
  }
}]

// 1.5 Set CNAME Records if any in Private DNS Zone 
module azPrivateDnsCnameRecordsDeployment 'privateDnsCnameRecord.bicep' = [for record in privateDnsZoneCnameRecords: if (!empty(record)) {
  name: !empty(privateDnsZoneCnameRecords) ? 'az-dns-private-cname-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-cname'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecord: record.cname
  }
}]

// 1.6 Set PTR Records if any in Private DNS Zone 
module azPrivateDnsPtrRecordsDeployment 'privateDnsPtrRecord.bicep' = [for record in privateDnsZonePtrRecords: if (!empty(record)) {
  name: !empty(privateDnsZonePtrRecords) ? 'az-dns-private-ptr-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-ptr'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.pointers
  }
}]

// 1.7 Set SRV Records if any in Private DNS Zone 
module azPrivateDnsSrvRecordsDeployment 'privateDnsSrvRecord.bicep' = [for record in privateDnsZoneSrvRecords: if (!empty(record)) {
  name: !empty(privateDnsZoneSrvRecords) ? 'az-dns-private-srv-${guid('${azPrivateDnsDeployment.name}/${record.name}')}' : '${azPrivateDnsDeployment.name}-record-srv'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsZoneName: privateDnsZoneName
    privateDnsZoneTtl: record.ttl
    privateDnsZoneRecordName: record.name
    privateDnsZoneRecords: record.services
  }
}]

// 2. Deploy VNet Links to the Private DNS Zones if applicable
module azPrivateDnsVirtualLinksDeployment 'privateDnsLink.bicep' = [for link in privateDnsZoneNetworkLinks: if (!empty(link)) {
  name: !empty(privateDnsZoneNetworkLinks) ? toLower('az-virtual-network-link-${guid('${azPrivateDnsDeployment.name}/${link.virtualLinkName}')}') : 'no-virtual-network-link-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateDnsName: azPrivateDnsDeployment.name
    privateDnsVirtualLinkName: link.virtualLinkName
    privateDnsVirtualNetworkName: link.virtualNetwork
  }
}]

output privateDnsZone object = azPrivateDnsDeployment
