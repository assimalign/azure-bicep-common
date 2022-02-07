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

@description('The name of the application insights to deploy')
param appInsightsName string

@description('The name of the existing Log Analytics Worspace')
param appAnalyticWorkspaceName string

@description('The name of the resource group for the existing log analytics worspace')
param appAnalyticWorkspaceResourceGroup string = resourceGroup().name

@description('Tags to associated the resource deployment')
param appInsightsTags object = {}


// 1. Get the existing log workspace to attach the insights component to
resource azAppLogAnalyticsWorkspaceDeployment 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: replace(replace(appAnalyticWorkspaceName, '@environment', environment), '@location', location)
  scope: resourceGroup(replace(replace(appAnalyticWorkspaceResourceGroup, '@environment', environment), '@location', location))
}

// 2. Deploy the new instance of App insights under the requested log workspace
resource azAppInsightsComponentsDeployment 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: replace(replace('${appInsightsName}', '@environment', environment), '@location', location)
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: azAppLogAnalyticsWorkspaceDeployment.id
  }
  tags: appInsightsTags
}

// 3. Return Deployment Output
output resource object = azAppInsightsComponentsDeployment
