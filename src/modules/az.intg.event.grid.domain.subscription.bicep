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

@description('')
param eventGridDomainName string

@description('')
param eventGridEventTypes array = []

@description('')
param eventGridEventLabels array = []

@description('')
param eventGridEventDeliveryHeaders array = []

@description('')
param eventGridEventFilters array = []

@description('')
param eventGridSubscriptionName string

@allowed([
  'AzureFunction'
  'EventHub'
  'HybridConnection'
  'ServiceBusQueue'
  'ServiceBusTopic'
  'StorageQueue'
  'WebHook'
])
param eventGridSubscriptionEndpointType string

@description('')
param eventGridSubscriptionEndpointName string

@description('')
param eventGridSubscriptionEndpointResourceGroup string

@description('The storage account blob container to dead letter undeliverable event messages')
param eventGridDeadLetterDestination object = {}

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

// 1. Get Event Grid Domain Resource
resource azEventGridDomainResource 'Microsoft.EventGrid/domains@2020-10-15-preview' existing = {
  name: replace('${eventGridDomainName}', '@environment', environment)
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if(eventGridSubscriptionUseMsi == true) {
  name: eventGridSubscriptionUseMsi == true ? replace(replace(eventGridSubscriptionName, '@environment', environment), '@location', location) : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainResource
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

// 3.
resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if(eventGridSubscriptionUseMsi == false) {
  name: eventGridSubscriptionUseMsi == false ? replace(replace(eventGridSubscriptionName, '@environment', environment), '@location', location) : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainResource
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

// 4. Return Deployment Output
output resource object = eventGridSubscriptionUseMsi == true ? azEventGridDomainWithMsiSubscriptionDeployment : azEventGridDomainWithoutMsiSubscriptionDeployment
