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
@description('The environment in which the resource(s) will be deployed.')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the application insights to deploy.')
param appInsightsName string

@description('The location/region the Azure App Insights instance will be deployed to.')
param appInsightsLocation string = resourceGroup().location

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

@description('The name of the existing Log Analytics Worspace.')
param appInsightsAnalyticWorkspaceName string

@description('The name of the resource group for the existing log analytics worspace.')
param appInsightsAnalyticWorkspaceResourceGroup string = resourceGroup().name

@description('')
param appInsightsNetworkSettings object = {}

@description('The tags to attach to the resource when deployed.')
param appInsightsTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Get the existing log workspace to attach the insights component to
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: formatName(appInsightsAnalyticWorkspaceName, affix, environment, region)
  scope: resourceGroup(formatName(appInsightsAnalyticWorkspaceResourceGroup, affix, environment, region))
}

// 2. Deploy the new instance of App insights under the requested log workspace
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: formatName(appInsightsName, affix, environment, region)
  location: appInsightsLocation
  kind: appInsightsKind
  properties: {
    Application_Type: appInsightsKind == 'web' ? 'web' : 'other'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: appInsightsNetworkSettings.?publicNetworkAccessForIngestion ?? 'Enabled'
    publicNetworkAccessForQuery: appInsightsNetworkSettings.?publicNetworkAccessForQuery ?? 'Enabled'
  }
  tags: union(appInsightsTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// 3. Return Deployment Output
output appInsights object = appInsights
