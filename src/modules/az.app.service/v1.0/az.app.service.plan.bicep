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

// **************************************************************************************** //
//               App Service Plan, App Insights, App Storage Act, and Apps Deploy           //
// **************************************************************************************** //

// 1. Get Existing ASE Environment if applicable
resource azAppServicePlanAseResource 'Microsoft.Web/hostingEnvironments@2022-03-01' existing = if (!empty(appServicePlanEnvironmentName)) {
  name: replace(replace(appServicePlanEnvironmentName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appServicePlanEnvironmentResourceGroup, '@environment', environment), '@region', region))
}

// 2. Creates an app service plan under an ASE if applicable
resource azAppServicePlanDeployment 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: replace(replace(appServicePlanName, '@environment', environment), '@region', region)
  location: appServicePlanLocation
  properties: {
    hostingEnvironmentProfile: any(!empty(appServicePlanEnvironmentName) ? {
      id: azAppServicePlanAseResource.id
    } : null)
  }
  kind: appServicePlanOs
  sku: any((environment == 'dev') ? {
    name: appServicePlanSku.dev
  } : any((environment == 'qa') ? {
    name: appServicePlanSku.qa
  } : any((environment == 'uat') ? {
    name: appServicePlanSku.uat
  } : any((environment == 'prd') ? {
    name: appServicePlanSku.prd
  } : {
    name: appServicePlanSku.default
  }))))
  tags:  union(appServicePlanTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 3. Return Deployment Output
output resource object = azAppServicePlanDeployment
