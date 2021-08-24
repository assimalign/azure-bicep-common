@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the ASE to deploy')
param aseName string
// @allowed([
//   'linux'
//   'windows'
// ])
// param os string = 'windows'
@allowed([
  'ASEV2'
  'ASEV1'
])
@description('The ASE version to be deployed. Default ASEV2')
param aseType string = 'ASEV2'

@description('A list of App Service Plans that will live under the Deployed ASE')
param aseAppServicePlans array = []

@description('The Virtual Network settings for the ASE')
param aseNetworkSettings object


// 1. Get the virtual network to attach to the ASE
resource azAppServiceEnvironmentVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: replace('${aseNetworkSettings.name}', '@environment', environment)
  scope: resourceGroup('${environment}-${aseNetworkSettings.resourceGroup}')
}

// 2. Begin Deployment of App Service Environment
resource azAppServiceEnvironmentDeployment 'Microsoft.Web/hostingEnvironments@2021-01-01' = {
  name: replace('${aseName}', '@environment', environment)
  location: resourceGroup().location
  kind: aseType
  properties: {
    virtualNetwork: {
      id: azAppServiceEnvironmentVirtualNetwork.id
      subnet: aseNetworkSettings.subnet
    }  
   internalLoadBalancingMode: any(aseNetworkSettings.internalIp == true ? 'Web, Publishing' : 'None')
  }
}

// 3. Deploy app services 
@batchSize(1) // Let's be gental and deploy one at a time
module azAppServiceEnvironmentAppPlansDeployment 'az.app.service.plan.bicep' = [for (plan, index) in aseAppServicePlans: if (!empty(plan)) {
  name: 'az-ase-app-service-plan-deployment-${padLeft(index, 3, '0')}'
  scope: resourceGroup()
  params: {
    environment: environment
    appServicePlanName: !empty(plan) ? plan.name : 'no-ase-app-plan'
    appServicePlanOs: !empty(plan) ? plan.os : 'windows'
    appServicePlanSku: !empty(plan) ? plan.sku : {}
    appServicePlanStorage: {
      storageAccountName: plan.storage
      storageAccountResourceGroup: 
    } !empty(plan) ? plan.storage : {}
    appServicePlanFunctionApps: !empty(plan) ? plan.funcapps : []
    appServicePlanWebApps: !empty(plan) ? plan.webapps : []
    appServicePlanHostingEnvironment: {
      aseName: azAppServiceEnvironmentDeployment.name
      aseResourceGroup: resourceGroup().name
    }
    appServicePlanInsights: !empty(plan) ? plan.insights : {}
  }
  dependsOn:[
    azAppServiceEnvironmentDeployment
  ]
}]


output resource object = azAppServiceEnvironmentDeployment
