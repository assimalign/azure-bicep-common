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

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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
  default: 'Free'
}

@description('')
param staticSiteEnvironmentVariables object = {}

@description('')
param staticSiteTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource staticSite 'Microsoft.Web/staticSites@2023-12-01' = {
  name: replace(replace(replace(staticSiteName, '@affix', affix), '@environment', environment), '@region', region)
  location: staticSiteLocation
  sku: any(contains(staticSiteSku, environment)
    ? {
        name: staticSiteSku[environment]
        tier: staticSiteSku[environment]
      }
    : {
        name: staticSiteSku.default
        tier: staticSiteSku.default
      })
  properties: {}
  resource staticSiteVariables 'config' = {
    name: 'appsettings'
    properties: mapValues(
      staticSiteEnvironmentVariables,
      variable =>
        formatName(
          contains(variable, environment) ? variable[environment] : variable.default,
          affix,
          environment,
          region
        )
    )
  }
  tags: union(staticSiteTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output staticSite object = staticSite
