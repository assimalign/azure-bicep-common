@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the app service plan to deploy')
param appServicePlanName string

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
}

@description('The name of the ASE to attach to the app service plan')
param appServicePlanAseName string = ''

@description('The resource group the ASE lives under')
param appServicePlanAseResourceGroup string = resourceGroup().name



// **************************************************************************************** //
//               App Service Plan, App Insights, App Storage Act, and Apps Deploy           //
// **************************************************************************************** //
// 1. Get Existing ASE Environment if applicable
resource azAppServicePlanAseResource 'Microsoft.Web/hostingEnvironments@2021-01-01' existing = if (!empty(appServicePlanAseName)) {
  name: replace(appServicePlanAseName, '@environment', environment)
  scope: resourceGroup(replace(appServicePlanAseResourceGroup, '@environment', environment))
}


// 2. Creates an app service plan under an ASE if applicable
resource azAppServicePlanDeployment 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: replace('${appServicePlanName}', '@environment', environment)
  location: resourceGroup().location
  properties:  {
    hostingEnvironmentProfile: any(!empty(appServicePlanAseName) ? {
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
    name: 'D1'
  })))) 
}
