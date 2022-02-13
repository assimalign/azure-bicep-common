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
param notificationHubName string

@description('The location/region to deploy the Azure Notification Hub.')
param notificationHubLocation string = resourceGroup().location

@description('The name of the notification namespace hub')
param notificationHubNamespaceName string


// 1. Deploy the notification namespace hub
resource azNotificationNamespaceHubDeployment 'Microsoft.NotificationHubs/namespaces/notificationHubs@2017-04-01' = {
  name: replace(replace('${notificationHubNamespaceName}/${notificationHubName}', '@environment', environment), '@region', region)
  location: notificationHubLocation
  properties: {
    name: replace(replace('${notificationHubNamespaceName}/${notificationHubName}', '@environment', environment), '@region', region)
  }
}
