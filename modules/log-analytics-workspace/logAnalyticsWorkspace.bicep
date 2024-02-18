@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the Analytic Log Workbook')
param logAnalyticsWorkspaceName string

@description('The location/region the Azure Log Analytical Workspace is deployed to.')
param logAnalyticsWorkspaceLocation string = resourceGroup().location

@description('The pricing tier for the Workbook')
param logAnalyticsWorkspaceSku object = {
  dev: 'PerGB2018'
  qa: 'PerGB2018'
  uat: 'PerGB2018'
  prd: 'PerGB2018'
  default: 'PerGB2018'
}

@description('The number of days to retain data')
param logAnalyticsWorkspaceRetention int = 30

@description('The Daily Quota of ingestion in GBs')
param logAnalyticsWorkspaceDailyQuota int = -1

@description('Enables or Disables public network access for data injestion')
param logAnalyticsWorkspacePublicNetworkAccessForIngestion string = 'Enabled'

@description('Enables or Disables public network access to query log analytics')
param logAnalyticsWorkspacePublicNetworkAccessForQuery string = 'Enabled'

@description('Tags to attach with the workspace deployment')
param logAnalyticsWorkspaceTags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: replace(replace(logAnalyticsWorkspaceName, '@environment', environment), '@region', region)
  location: logAnalyticsWorkspaceLocation
  properties: {
    publicNetworkAccessForIngestion: logAnalyticsWorkspacePublicNetworkAccessForIngestion
    publicNetworkAccessForQuery: logAnalyticsWorkspacePublicNetworkAccessForQuery
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsWorkspaceDailyQuota
    }
    retentionInDays: logAnalyticsWorkspaceRetention
    sku: any(contains(logAnalyticsWorkspaceSku, environment) ? {
      name: logAnalyticsWorkspaceSku[environment]
    } : {
      name: logAnalyticsWorkspaceSku.default
    })
  }
  tags: union(logAnalyticsWorkspaceTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

output logAnalyticsWorkspace object = logAnalyticsWorkspace
