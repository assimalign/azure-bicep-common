
@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Analytic Log Workbook')
param workspaceName string

@description('The pricing tier for the Workbook')
param workspaceSku object = {}

@description('The number of days to retain data')
param workspaceRetention int = 30

@description('The Daily Quota of ingestion in GBs')
param workspaceDailyQuota int = -1

@description('Enables or Disables public network access for data injestion')
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Enables or Disables public network access to query log analytics')
param publicNetworkAccessForQuery string = 'Enabled'

@description('Tags to attach with the workspace deployment')
param workspaceTags object = {}




resource azAppLogAnalyticsWorkspaceDeployment 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: replace(workspaceName, '@environment', environment)
  location: resourceGroup().location
  properties: {
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    workspaceCapping: {
      dailyQuotaGb: workspaceDailyQuota
    }
    retentionInDays: workspaceRetention
    sku: any(environment == 'dev' ? {
      name: workspaceSku.dev 
    } : any(environment == 'qa' ? {
      name: workspaceSku.qa 
    } : any(environment == 'uat' ? {
      name: workspaceSku.uat 
    } : any(environment == 'prd' ? {
      name: workspaceSku.prd 
    } : {
      name: 'PerGB2018'
    }))))
  }
  tags: workspaceTags
}


output resource object = azAppLogAnalyticsWorkspaceDeployment
