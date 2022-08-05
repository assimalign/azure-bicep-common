@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('The name of the Notification Namespace to deploy')
param notificationHubNamespaceName string

@description('The location/region the Azure Notification Namespace will be deployed to.')
param notificationHubNamespaceLocation string = resourceGroup().location

@description('A list of Notification Hubs to deploy under the Notificaiton Namespace')
param notificationHubNamespaceHubs array = []

@description('The pricing tier for the resource. Choose wisely')
param notificationHubNamespaceSku object = {
  dev: 'Free'
  qa: 'Free'
  uat: 'Free'
  prd: 'Free'
  default: 'Free'
}

@description('The access policies to the Notification Namespace')
param notificationHubNamespacePolicies array = []

@description('')
param notificationHubNamespaceTags object = {}

// 1. Deploy the Notification Namespace
resource azNotificationHubNamespaceDeployment 'Microsoft.NotificationHubs/namespaces@2017-04-01' = {
  name: replace(replace('${notificationHubNamespaceName}', '@environment', environment), '@region', region)
  properties: {
    namespaceType: 'NotificationHub'
  }
  location: notificationHubNamespaceLocation
  sku: any(environment == 'dev' && !empty(notificationHubNamespaceSku) ? {
    name: notificationHubNamespaceSku.dev
  } : any(environment == 'qa' && !empty(notificationHubNamespaceSku) ? {
    name: notificationHubNamespaceSku.qa
  } : any(environment == 'uat' && !empty(notificationHubNamespaceSku) ? {
    name: notificationHubNamespaceSku.uat
  } : any(environment == 'qa' && !empty(notificationHubNamespaceSku) ? {
    name: notificationHubNamespaceSku.prd
  } : {
    name: notificationHubNamespaceSku.default
  }))))
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
module azNotificationNamespaceHubsDeployment 'az.notification.namespace.hub.bicep' = [for hub in notificationHubNamespaceHubs: if (!empty(hub)) {
  name: !empty(notificationHubNamespaceHubs) ? replace(replace(hub.notificationHubName, '@environment', environment), '@region', region) : 'no-hubs-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    notificationHubLocation: notificationHubNamespaceLocation
    notificationHubName: hub.notificationHubName
    notificationHubNamespaceName: notificationHubNamespaceName
  }
  dependsOn: [
    azNotificationHubNamespaceDeployment
  ]
}]

output notificationHubNamespace object = azNotificationHubNamespaceDeployment
