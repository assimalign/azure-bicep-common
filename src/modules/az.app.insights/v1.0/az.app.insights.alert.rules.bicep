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

@description('')
param appInsightsAlertRuleName string

@description('')
param appInsightsAlertRuleDescription string = 'Activity Log Alert for ${replace(replace(appInsightsAlertRuleName, '@environment', environment), '@region', region)}'

@description('')
param appInsightsAlertRuleEnabled bool = true

@description('')
param appInsightsAlertRuleActionGroups array

@minLength(1)
@description('')
param appInsightsAlertRuleConditions array

var actionsGroups = [for group in appInsightsAlertRuleActionGroups: {
   actionGroupId: resourceId('Microsoft.Insights/actionGroups', replace(replace(group.name, '@environment', environment), '@region', region))
}]

resource azAppInsightsAlertRuleDeployment 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
   name: replace(replace(appInsightsAlertRuleName, '@environment', environment), '@region', region)
   location: resourceGroup().location
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
}
