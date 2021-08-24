@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the application insights to deploy')
param appInsightsName string

@description('The name of the existing Log Analytics Worspace')
param appAnalyticWorkspaceName string

@description('The name of the resource group for the existing log analytics worspace')
param appAnalyticWorkspaceResourceGroup string = resourceGroup().name

@description('')
param appInsightsTags object = {}



resource azAppLogAnalyticsWorkspaceDeployment 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: replace(appAnalyticWorkspaceName, '@environment', environment)
  scope: resourceGroup(replace(appAnalyticWorkspaceResourceGroup, '@environment', environment))
}


resource azAppInsightsComponentsDeployment 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: replace('${appInsightsName}', '@environment', environment)
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: azAppLogAnalyticsWorkspaceDeployment.id
  }
  tags: appInsightsTags
}

output resource object = azAppInsightsComponentsDeployment
