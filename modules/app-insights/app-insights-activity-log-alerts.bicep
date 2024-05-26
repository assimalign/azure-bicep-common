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

func format(name string, env string, region string) string => replace(replace(name, '@environment', env), '@region', region)

resource appInsightsActivityLogAlerts 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: format(appInsightsActivityLogAlertName, environment, region)
  properties: {
    enabled: appInsightsActivityLogAlertEnabled
    description: appInsightsActivityLogAlertDescription
    actions: {
      actionGroups: [for group in appInsightsActivityLogAlertActionGroups: {
        actionGroupId: resourceId('Microsoft.Insights/actionGroups', format(group.name, environment, region))
      }]
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

output appInsightsActivityLogAlerts object = appInsightsActivityLogAlerts
