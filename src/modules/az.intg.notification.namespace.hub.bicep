@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('The name of the Notification Namespace to deploy')
param notificationNamespaceName string

@description('The name of the notification namespace hub')
param notificationNamespaceHubName string



resource azNotificationNamespaceHubDeployment 'Microsoft.NotificationHubs/namespaces/notificationHubs@2017-04-01' = {
  name: replace('${notificationNamespaceName}/${notificationNamespaceHubName}', '@environment', environment)
  location: resourceGroup().location
  properties: {
    name: replace('${notificationNamespaceName}/${notificationNamespaceHubName}', '@environment', environment)
  }
}
