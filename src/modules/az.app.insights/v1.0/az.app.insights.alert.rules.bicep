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
param appInsightsAlertRuleName string

@description('')
param appInsightsAlertRuleDescription string = 'Activity Log Alert for ${replace(replace(appInsightsAlertRuleName, '@environment', environment), '@region', region)}'

@description('')
param appInsightsAlertRuleEnabled bool = true

@description('')
param appInsightsAlertRuleActionGroups array

@minLength(1)
@description('The conditional rules used to define an alert.')
param appInsightsAlertRuleConditions array

@description('The tags to attach to the resource when deployed.')
param appInsightsAlertRuleTags object = {}

var actionsGroups = [for group in appInsightsAlertRuleActionGroups: {
   actionGroupId: resourceId('Microsoft.Insights/actionGroups', replace(replace(group.name, '@environment', environment), '@region', region))
}]

resource azAppInsightsAlertRuleDeployment 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
   name: replace(replace(appInsightsAlertRuleName, '@environment', environment), '@region', region)
   location: 'global'
   properties: {
      enabled: appInsightsAlertRuleEnabled
      description: appInsightsAlertRuleDescription
      condition: {
         allOf: appInsightsAlertRuleConditions
      }
      actions: {
         actionGroups: actionsGroups
      }
      scopes: []
   }
   tags: union(appInsightsAlertRuleTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
   })
}

output appInsightsAllertRule object = azAppInsightsAlertRuleDeployment
