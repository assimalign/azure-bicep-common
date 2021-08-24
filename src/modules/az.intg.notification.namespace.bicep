@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the Notification Namespace to deploy')
param notificationNamespaceName string

@description('A list of Notification Hubs to deploy under the Notificaiton Namespace')
param notificationNamespaceHubs array = []

@description('The pricing tier for the resource. Choose wisely')
param notificationNamespaceSku object = {}

@description('The access policies to the Notification Namespace')
param notificationNamespacePolicies array = []




resource azNotificationNamespaceDeployment 'Microsoft.NotificationHubs/namespaces@2017-04-01' = {
  name: replace('${notificationNamespaceName}', '@environment', environment)
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

  resource azNotificationNamespaceAuthPolicyDeployment 'AuthorizationRules' = [for policy in notificationNamespacePolicies: if (!empty(policy)) {
    name: !empty(notificationNamespacePolicies) ? policy.name : 'no-nh-polcies-to-deploy'
    properties: {
      rights: !empty(notificationNamespacePolicies) ? policy.permissions : []
    }
  }]
}


module azNotificationNamespaceHubsDeployment 'az.intg.notification.namespace.hub.bicep' = [for hub in notificationNamespaceHubs: if (!empty(hub)){
  name: !empty(notificationNamespaceHubs) ? replace(hub.name, '@environment', environment) : 'no-hubs-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    notificationNamespaceName: notificationNamespaceName
    notificationNamespaceHubName: hub.name
  }
  dependsOn: [
    azNotificationNamespaceDeployment
  ]
}]
