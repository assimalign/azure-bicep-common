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
  demo: 'F1'
  stg: 'F1'
  sbx: 'F1'
  test: 'F1'
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

@description('Custom Attributes to attach to the app service plan deployment')
param appServicePlanTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: formatName(appServicePlanName, affix, environment, region)
  location: appServicePlanLocation
  properties: {
    hostingEnvironmentProfile: !empty(appServicePlanEnvironmentName)
      ? {
          id: resourceId(
            formatName(appServicePlanEnvironmentResourceGroup, affix, environment, region),
            'Microsoft.Web/hostingEnvironments',
            formatName(appServicePlanEnvironmentName, affix, environment, region)
          )
        }
      : null
  }
  kind: appServicePlanOs
  sku: contains(appServicePlanSku, environment)
    ? {
        name: appServicePlanSku[environment].name
        capacity: appServicePlanSku[environment].capacity
      }
    : {
        name: appServicePlanSku.default.name
        capacity: appServicePlanSku.default.capacity
      }
  tags: union(appServicePlanTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 3. Return Deployment Output
output appServicePlan object = appServicePlan
