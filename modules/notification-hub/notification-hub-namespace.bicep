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

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('The name of the Notification Namespace to deploy')
param notificationHubNamespaceName string

@description('The location/region the Azure Notification Namespace will be deployed to.')
param notificationHubNamespaceLocation string = resourceGroup().location

@description('A list of Notification Hubs to deploy under the Notificaiton Namespace')
param notificationHubNamespaceHubs array = []

@description('The pricing tier for the resource. Choose wisely')
param notificationHubNamespaceSku object = {
  default: 'Free'
}

@description('The access policies to the Notification Namespace')
param notificationHubNamespacePolicies array = []

@description('')
param notificationHubNamespaceTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy the Notification Namespace
resource notificationHubNamespace 'Microsoft.NotificationHubs/namespaces@2023-09-01' = {
  name: formatName(notificationHubNamespaceName, affix, environment, region)
  location: notificationHubNamespaceLocation
  sku: any(contains(notificationHubNamespaceSku, environment) ? {
    name: notificationHubNamespaceSku[environment]
  } : {
    name: notificationHubNamespaceSku.default
  })

  // 1.1 If applicable, deploy authorization rules
  resource azNotificationNamespaceAuthPolicyDeployment 'AuthorizationRules' = [for policy in notificationHubNamespacePolicies: if (!empty(policy)) {
    name: !empty(notificationHubNamespacePolicies) ? policy.notificationHubPolicyName : 'no-nh-polcies-to-deploy'
    properties: {
      rights: !empty(notificationHubNamespacePolicies) ? policy.notificationHubPolicyPermissions : []
    }
  }]
  tags: union(notificationHubNamespaceTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

// 2. Deploy the Notification Namespace Hubs, if any
module azNotificationNamespaceHubsDeployment 'notification-hub-namespace-hub.bicep' = [for hub in notificationHubNamespaceHubs: if (!empty(hub)) {
  name: !empty(notificationHubNamespaceHubs) ? formatName(hub.notificationHubName, affix, environment, region) : 'no-hubs-to-deploy'
  scope: resourceGroup()
  params: {
    affix: affix
    region: region
    environment: environment
    notificationHubLocation: notificationHubNamespaceLocation
    notificationHubName: hub.notificationHubName
    notificationHubNamespaceName: notificationHubNamespaceName
  }
  dependsOn: [
    notificationHubNamespace
  ]
}]

output notificationHubNamespace object = notificationHubNamespace
