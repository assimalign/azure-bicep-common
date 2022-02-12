@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name')
param region string = ''

@description('The name of the Notification Namespace to deploy')
param notificationNamespaceName string

@description('A list of Notification Hubs to deploy under the Notificaiton Namespace')
param notificationNamespaceHubs array = []

@description('The pricing tier for the resource. Choose wisely')
param notificationNamespaceSku object = {}

@description('The access policies to the Notification Namespace')
param notificationNamespacePolicies array = []

// 1. Deploy the Notification Namespace
resource azNotificationNamespaceDeployment 'Microsoft.NotificationHubs/namespaces@2017-04-01' = {
  name: replace(replace('${notificationNamespaceName}', '@environment', environment), '@region', region)
  properties: {
    namespaceType: 'NotificationHub'
  }
  location: resourceGroup().location
  sku: any(environment == 'dev' && !empty(notificationNamespaceSku) ? {
    name: notificationNamespaceSku.dev
  } : any(environment == 'qa' && !empty(notificationNamespaceSku) ? {
    name: notificationNamespaceSku.qa
  } : any(environment == 'uat' && !empty(notificationNamespaceSku) ? {
    name: notificationNamespaceSku.uat
  } : any(environment == 'qa' && !empty(notificationNamespaceSku) ? {
    name: notificationNamespaceSku.prd
  } : {
    name: 'Free'
  }))))

  // 1.1 If applicable, deploy authorization rules
  resource azNotificationNamespaceAuthPolicyDeployment 'AuthorizationRules' = [for policy in notificationNamespacePolicies: if (!empty(policy)) {
    name: !empty(notificationNamespacePolicies) ? policy.name : 'no-nh-polcies-to-deploy'
    properties: {
      rights: !empty(notificationNamespacePolicies) ? policy.permissions : []
    }
  }]
}

// 2. Deploy the Notification Namespace Hubs, if any
module azNotificationNamespaceHubsDeployment 'az.notification.namespace.hub.bicep' = [for hub in notificationNamespaceHubs: if (!empty(hub)) {
  name: !empty(notificationNamespaceHubs) ? replace(replace(hub.name, '@environment', environment), '@region', region) : 'no-hubs-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    notificationNamespaceName: notificationNamespaceName
    notificationNamespaceHubName: hub.name
  }
  dependsOn: [
    azNotificationNamespaceDeployment
  ]
}]
