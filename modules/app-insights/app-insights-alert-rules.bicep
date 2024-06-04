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

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource appInsightsAllertRule 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: formatName(appInsightsAlertRuleName, affix, environment, region)
  location: 'global'
  properties: {
    enabled: appInsightsAlertRuleEnabled
    description: appInsightsAlertRuleDescription
    condition: {
      allOf: appInsightsAlertRuleConditions
    }
    actions: {
      actionGroups: [
        for group in appInsightsAlertRuleActionGroups: {
          actionGroupId: resourceId(
            'Microsoft.Insights/actionGroups',
            formatName(group.name, affix, environment, region)
          )
        }
      ]
    }
    scopes: []
  }
  tags: union(appInsightsAlertRuleTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output appInsightsAllertRule object = appInsightsAllertRule
