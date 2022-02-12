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

@description('The name of the Notification Namespace to deploy')
param notificationNamespaceName string

@description('The name of the notification namespace hub')
param notificationNamespaceHubName string


// 1. Deploy the notification namespace hub
resource azNotificationNamespaceHubDeployment 'Microsoft.NotificationHubs/namespaces/notificationHubs@2017-04-01' = {
  name: replace(replace('${notificationNamespaceName}/${notificationNamespaceHubName}', '@environment', environment), '@region', region)
  location: resourceGroup().location
  properties: {
    name: replace(replace('${notificationNamespaceName}/${notificationNamespaceHubName}', '@environment', environment), '@region', region)
  }
}
