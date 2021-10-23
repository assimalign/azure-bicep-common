@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The name of an existing Event Grid Domain to deploy the new Subscription to')
param eventGridDomainName string

@description('The name of an existing Event Grid Domain Topic to deploy the new Subscription to')
param eventGridDomainTopicName string

@description('The name of the new Subscriptio to deploy')
param eventGridSubscriptionName string

@description('Custom tags for events being delivered to the subscription')
param eventGridEventTypes array = []

@description('Custom query for filtering event message to subscription')
param eventGridEventFilters array = []

@description('Cusom labels to categorize the event grid subscriptions')
param eventGridEventLabels array = []

@description('')
param eventGridEventDeliveryHeaders array = []

@description('The storage account blob container to dead letter undeliverable event messages')
param eventGridDeadLetterDestination object = {}

@allowed([
  'AzureFunction'
  'EventHub'
  'HybridConnection'
  'ServiceBusQueue'
  'ServiceBusTopic'
  'StorageQueue'
  'WebHook'
])
@description('The event grid handler to receive the event subscription message')
param eventGridSubscriptionEndpointType string

@description('The name of the event grid handler')
param eventGridSubscriptionEndpointName string

@description('the name of the resource group the event event grid handler lives in')
param eventGridSubscriptionEndpointResourceGroup string

@description('')
param eventGridSubscriptionUseMsi bool = false


var headers = [for header in eventGridEventDeliveryHeaders: {
  type: header.type
  name: header.name
  properties: any(header.type == 'Dynamic' ? {
    sourceField: header.value
  } : {
    value: header.value
    isSecret: false
  })
}]

// 1. Get an Existing Event Grid Domain Resource
resource azEventGridDomainTopicResource 'Microsoft.EventGrid/domains/topics@2021-06-01-preview' existing = {
  name: replace(replace('${eventGridDomainName}/${eventGridDomainTopicName}', '@environment', environment), '@location', location)
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if(eventGridSubscriptionUseMsi == true) {
  name: eventGridSubscriptionUseMsi == true ? replace(replace(eventGridSubscriptionName, '@environment', environment), '@location', location) : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridSubscriptionEndpointType == 'AzureFunction' ? {
        endpointType: 'AzureFunction'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
        }
      } : any(eventGridSubscriptionEndpointType == 'ServiceBusQueue' ? {
        endpointType: 'ServiceBusQueue'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
        }
      } : any(eventGridSubscriptionEndpointType == 'ServiceBusTopic' ? {
        endpointType: 'ServiceBusTopic'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
        }
      } : any(eventGridSubscriptionEndpointType == 'EventHub' ? {
        endpointType: 'EventHub'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
        }
      } : any(eventGridSubscriptionEndpointType == 'StorageQueue' ? {
        endpointType: 'StorageQueue'
        properties: {
          deliveryAttributeMappings: headers
          queueName: replace(last(split('${eventGridSubscriptionEndpointName}', '/')), '@environment', environment)
          resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridSubscriptionEndpointName, '/'))), '@environment', environment), '@location', location)
        }
      } : {})))))
      identity: {
        type: 'SystemAssigned'
      }
    }
    deadLetterWithResourceIdentity: !empty(eventGridDeadLetterDestination) ? {
      deadLetterDestination: {
        endpointType: 'StorageBlob'
        properties: {
          blobContainerName: eventGridDeadLetterDestination.storageAccountContainerName
          resourceId: replace(replace(az.resourceId(eventGridDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDeadLetterDestination.storageAccountName), '@environment', environment), '@location', location)
        }
      }
      identity: {
        type: 'SystemAssigned'
      }
    } : json('null')
    filter: any(empty(eventGridEventTypes) ? {
      advancedFilters: eventGridEventFilters
    } : {
      advancedFilters: eventGridEventFilters
      includedEventTypes: eventGridEventTypes
    })
  }
}


resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if(eventGridSubscriptionUseMsi == false) {
  name: eventGridSubscriptionUseMsi == false ? replace(replace(eventGridSubscriptionName, '@environment', environment), '@location', location) : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination:  any(eventGridSubscriptionEndpointType == 'AzureFunction' ? {
      endpointType: 'AzureFunction'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
      }
    } : any(eventGridSubscriptionEndpointType == 'ServiceBusQueue' ? {
      endpointType: 'ServiceBusQueue'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
      }
    } : any(eventGridSubscriptionEndpointType == 'ServiceBusTopic' ? {
      endpointType: 'ServiceBusTopic'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
      }
    } : any(eventGridSubscriptionEndpointType == 'EventHub' ? {
      endpointType: 'EventHub'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridSubscriptionEndpointName, '/')[0], split(eventGridSubscriptionEndpointName, '/')[1]), '@environment', environment), '@location', location)
      }
    } : any(eventGridSubscriptionEndpointType == 'StorageQueue' ? {
      endpointType: 'StorageQueue'
      properties: {
        deliveryAttributeMappings: headers
        queueName: replace(last(split('${eventGridSubscriptionEndpointName}', '/')), '@environment', environment)
        resourceId: replace(replace(az.resourceId(eventGridSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridSubscriptionEndpointName, '/'))), '@environment', environment), '@location', location)
      }
    } : {})))))
    deadLetterDestination: !empty(eventGridDeadLetterDestination) ? {
      endpointType: 'StorageBlob'
      properties: {
        deliveryAttributeMappings: headers
        blobContainerName: eventGridDeadLetterDestination.storageAccountContainerName
        resourceId: replace(replace(az.resourceId(eventGridDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDeadLetterDestination.storageAccountName), '@environment', environment), '@location', location)
      }
    } : json('null')
    filter: any(empty(eventGridEventTypes) ? {
      advancedFilters: eventGridEventFilters
    } : {
      advancedFilters: eventGridEventFilters
      includedEventTypes: eventGridEventTypes
    })
  }
}

// 8. Return Deployment Output
output resource object = eventGridSubscriptionUseMsi == true ? azEventGridDomainWithMsiSubscriptionDeployment : azEventGridDomainWithoutMsiSubscriptionDeployment
