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

@description('The name of the Notification Namespace to deploy')
param notificationHubName string

@description('The location/region to deploy the Azure Notification Hub.')
param notificationHubLocation string = resourceGroup().location

@description('The name of the notification namespace hub')
param notificationHubNamespaceName string

@description('')
param notificationHubTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// 1. Deploy the notification namespace hub
resource notificationHubNamespaceHub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2017-04-01' = {
  name: formatName('${notificationHubNamespaceName}/${notificationHubName}', affix, environment, region)
  location: notificationHubLocation
  properties: {
    name: formatName('${notificationHubNamespaceName}/${notificationHubName}', affix, environment, region)
  }
  tags: union(notificationHubTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output notificationHubNamespaceHub object = notificationHubNamespaceHub
