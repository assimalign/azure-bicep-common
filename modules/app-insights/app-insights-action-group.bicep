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

@description('A descriptive name for the Action Group.')
param appInsightsActionGroupName string

@description('The location/region the Azure App Insights Action Group will be deployed to.')
param appInsightsActionGroupLocation string = resourceGroup().location

@description('A friendly name for the Action Group.')
param appInsightsActionGroupShortName string = appInsightsActionGroupName

@description('Enable App Insights Action group to receive notifications.')
param appInsightsActionGroupEnabled bool = true

@description('An object specifying a group of notification receivers for a particular action.')
param appInsightsActionGroupReceivers object

@description('The tags to attach to the resource when deployed.')
param appInsightsActionGroupTags object = {}

// Deploys an Alert Action Group
resource appInsightsActionGroup 'Microsoft.Insights/actionGroups@2022-04-01' = {
  name: replace(replace(appInsightsActionGroupName, '@environment', environment), '@region', region)
  location: appInsightsActionGroupLocation
  properties: union({
    groupShortName: appInsightsActionGroupShortName
    enabled: appInsightsActionGroupEnabled
  }, appInsightsActionGroupReceivers)
  tags: union(appInsightsActionGroupTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output appInsightsActionGroup object = appInsightsActionGroup
