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

@description('')
param appInsightsActivityLogAlertName string

@description('')
param appInsightsActivityLogAlertDescription string = 'Activity Log Alert for ${replace(replace(appInsightsActivityLogAlertName, '@environment', environment), '@region', region)}'

@description('')
param appInsightsActivityLogAlertEnabled bool = true

@description('')
param appInsightsActivityLogAlertActionGroups array

@minLength(1)
@description('')
param appInsightsActivityLogAlertConditions array

@description('The tags to attach to the resource when deployed')
param appInsightsActivityLogAlertTags object = {}

var actionsGroups = [for group in appInsightsActivityLogAlertActionGroups: {
  actionGroupId: resourceId('Microsoft.Insights/actionGroups', replace(replace(group.name, '@environment', environment), '@region', region))
}]

resource azAppInsightsActivityLogAlertsDeployemnt 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: replace(replace(appInsightsActivityLogAlertName, '@environment', environment), '@region', region)
  properties: {
    enabled: appInsightsActivityLogAlertEnabled
    description: appInsightsActivityLogAlertDescription
    actions: {
      actionGroups: actionsGroups
    }
    condition: {
      allOf: appInsightsActivityLogAlertConditions
    }
    scopes: [
      subscription().id
    ]
  }
  tags: union(appInsightsActivityLogAlertTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output appInsightsActivityLogAlerts object = azAppInsightsActivityLogAlertsDeployemnt
