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

@description('')
param publicIpPrefixName string

@allowed([
  'Regional'
  'Global'
])
@description('')
param publicIpPrefixTier string = 'Global'

@allowed([
  'IPv4'
  'IPv6'
])
@description('')
param publicIpPrefixAddressVersion string = 'IPv4'

@description('')
param publicIpPrefixTags object = {}

resource publicIpPrefix 'Microsoft.Network/publicIPPrefixes@2023-05-01' = {
  name: replace(replace(publicIpPrefixName, '@environment', environment), '@region', region)
  sku: {
    name: 'Standard'
    tier: publicIpPrefixTier
  }
  properties: {
    publicIPAddressVersion: publicIpPrefixAddressVersion
  }
  tags: union(publicIpPrefixTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output publicIpPrefix object = publicIpPrefix
