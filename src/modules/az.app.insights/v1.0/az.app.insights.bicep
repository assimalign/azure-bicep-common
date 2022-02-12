@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the application insights to deploy')
param appInsightsName string

@allowed([
  'web'
  'ios'
  'other'
  'store'
  'java'
  'phone'
])
@description('')
param appInsightsKind string = 'web'

@description('The name of the existing Log Analytics Worspace')
param appInsightsAnalyticWorkspaceName string

@description('The name of the resource group for the existing log analytics worspace')
param appInsightsAnalyticWorkspaceResourceGroup string = resourceGroup().name

@description('Tags to associated the resource deployment')
param appInsightsTags object = {}

// 1. Get the existing log workspace to attach the insights component to
resource azAppLogAnalyticsWorkspaceDeployment 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: replace(replace(appInsightsAnalyticWorkspaceName, '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace(appInsightsAnalyticWorkspaceResourceGroup, '@environment', environment), '@region', region))
}

// 2. Deploy the new instance of App insights under the requested log workspace
resource azAppInsightsComponentsDeployment 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: replace(replace('${appInsightsName}', '@environment', environment), '@region', region)
  location: resourceGroup().location
  kind: appInsightsKind
  properties: {
    Application_Type: appInsightsKind == 'web' ? 'web' : 'other'
    WorkspaceResourceId: azAppLogAnalyticsWorkspaceDeployment.id
   
  }
  tags: appInsightsTags
}



// 3. Return Deployment Output
output resource object = azAppInsightsComponentsDeployment
