@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

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
param staticSiteLocation string 

@description('The pricing tier for the static site')
param staticSiteSku object


resource azStaticSiteDeployment 'Microsoft.Web/staticSites@2021-01-15' = {
  name: replace(replace(staticSiteName, '@environment', environment), '@location', location)
  location: staticSiteLocation
  sku: any(environment == 'dev' ? {
    name: staticSiteSku.dev
    tier: staticSiteSku.dev
  }  : any(environment == 'qa' ? {
    name: staticSiteSku.qa
    tier: staticSiteSku.qa
  }  : any(environment == 'uat' ? {
    name: staticSiteSku.uat
    tier: staticSiteSku.uat
  }  : any(environment == 'prd' ? {
    name: staticSiteSku.prd
    tier: staticSiteSku.prd
  }  : {
    name: 'Free'
    tier: 'Free'
  }))))
  properties: {
     
  }
}


output resource object = azStaticSiteDeployment
