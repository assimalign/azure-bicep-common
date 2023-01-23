@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('The name of the static site')
param staticSiteName string

@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'eastasia'
  'westeurope'
])
@description('The static site location')
param staticSiteLocation string = 'eastus2'

@description('The pricing tier for the static site')
param staticSiteSku object = {
  dev: 'Free'
  qa: 'Free'
  uat: 'Free'
  prd: 'Free'
  default: 'Free'
}

@description('')
param staticSiteTags object = {}

resource azStaticSiteDeployment 'Microsoft.Web/staticSites@2022-03-01' = {
  name: replace(replace(staticSiteName, '@environment', environment), '@region', region)
  location: staticSiteLocation
  sku: any(contains(staticSiteSku, environment) ? {
    name: staticSiteSku[environment]
    tier: staticSiteSku[environment]
  } : {
    name: staticSiteSku.default
    tier: staticSiteSku.default
  })
  properties: {
     
  }
  tags: union(staticSiteTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output staticSite object = azStaticSiteDeployment
