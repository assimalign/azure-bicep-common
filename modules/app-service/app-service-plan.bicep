@allowed([
  'none'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'none'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the app service plan to deploy')
param appServicePlanName string

@description('')
param appServicePlanLocation string = resourceGroup().location

@allowed([
  'linux'
  'windows'
])
@description('The target operating system for the app service plan')
param appServicePlanOs string = 'windows'

@description('Dev/Test Env: F1(Free), D1($9.49m), B1($54.75)')
param appServicePlanSku object = {
  dev: 'F1'
  qa: 'F1'
  uat: 'F1'
  prd: 'F1'
  default: 'F1'
}

@description('The name of the ASE to attach to the app service plan')
param appServicePlanEnvironmentName string = ''

@description('The resource group the ASE lives under')
param appServicePlanEnvironmentResourceGroup string = resourceGroup().name

@description('')
param appServicePlanTags object = {}


// 1. Get Existing ASE Environment if applicable
resource appServiceEnvironment 'Microsoft.Web/hostingEnvironments@2023-01-01' existing = if (!empty(appServicePlanEnvironmentName)) {
  name: replace(replace(appServicePlanEnvironmentName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServicePlanEnvironmentResourceGroup, '@environment', environment), '@region', region))
}

// 2. Creates an app service plan under an ASE if applicable
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: replace(replace(appServicePlanName, '@environment', environment), '@region', region)
  location: appServicePlanLocation
  properties: {
    hostingEnvironmentProfile: any(!empty(appServicePlanEnvironmentName) ? {
      id: appServiceEnvironment.id
    } : null)
  }
  kind: appServicePlanOs
  sku: any(!empty(environment) && contains(appServicePlanSku, environment) ? {
    name: appServicePlanSku[environment].name
    capacity: appServicePlanSku[environment].capacity
  } : {
    name: appServicePlanSku.default.name
    capacity: appServicePlanSku.default.capacity
  })
  tags:  union(appServicePlanTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 3. Return Deployment Output
output appServicePlan object = appServicePlan
