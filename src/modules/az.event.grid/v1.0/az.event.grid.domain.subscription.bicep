@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('')
param eventGridDomainName string

@description('')
param eventGridDomainSubscriptionName string

@description('')
param eventGridDomainSubscriptionEventTypes array = []

@description('')
param eventGridDomainSubscriptionEventLabels array = []

@description('')
param eventGridDomainSubscriptionEventFilters array = []

@description('')
param eventGridDomainSubscriptionEventHeaders array = []

@allowed([
  'AzureFunction'
  'EventHub'
  'HybridConnection'
  'ServiceBusQueue'
  'ServiceBusTopic'
  'StorageQueue'
  'WebHook'
])
@description('')
param eventGridDomainSubscriptionEndpointType string

@description('')
param eventGridDomainSubscriptionEndpointName string

@description('')
param eventGridDomainSubscriptionEndpointResourceGroup string

@description('The storage account blob container to dead letter undeliverable event messages')
param eventGridDomainSubscriptionDeadLetterDestination object = {}

@description('')
param eventGridDomainSubscriptionMsiEnabled bool = false

var headers = [for header in eventGridDomainSubscriptionEventHeaders: {
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
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if (eventGridDomainSubscriptionMsiEnabled == true) {
  name: eventGridDomainSubscriptionMsiEnabled == true ? replace(replace(eventGridDomainSubscriptionName, '@environment', environment), '@region', region) : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainResource
  properties: {
    labels: eventGridDomainSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridDomainSubscriptionEndpointType == 'AzureFunction' ? {
        endpointType: 'AzureFunction'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
        }
      } : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusQueue' ? {
        endpointType: 'ServiceBusQueue'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
        }
      } : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusTopic' ? {
        endpointType: 'ServiceBusTopic'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
        }
      } : any(eventGridDomainSubscriptionEndpointType == 'EventHub' ? {
        endpointType: 'EventHub'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
        }
      } : any(eventGridDomainSubscriptionEndpointType == 'StorageQueue' ? {
        endpointType: 'StorageQueue'
        properties: {
          deliveryAttributeMappings: headers
          queueName: replace(last(split('${eventGridDomainSubscriptionEndpointName}', '/')), '@environment', environment)
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridDomainSubscriptionEndpointName, '/'))), '@environment', environment), '@region', region)
        }
      } : {})))))
      identity: {
        type: 'SystemAssigned'
      }
    }
    deadLetterWithResourceIdentity: !empty(eventGridDomainSubscriptionDeadLetterDestination) ? {
      deadLetterDestination: {
        endpointType: 'StorageBlob'
        properties: {
          blobContainerName: eventGridDomainSubscriptionDeadLetterDestination.storageAccountContainerName
          resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDomainSubscriptionDeadLetterDestination.storageAccountName), '@environment', environment), '@region', region)
        }
      }
      identity: {
        type: 'SystemAssigned'
      }
    } : json('null')
    filter: any(empty(eventGridDomainSubscriptionEventTypes) ? {
      advancedFilters: eventGridDomainSubscriptionEventFilters
    } : {
      advancedFilters: eventGridDomainSubscriptionEventFilters
      includedEventTypes: eventGridDomainSubscriptionEventTypes
    })
  }
}

resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if (eventGridDomainSubscriptionMsiEnabled == false) {
  name: eventGridDomainSubscriptionMsiEnabled == false ? replace(replace(eventGridDomainSubscriptionName, '@environment', environment), '@region', region) : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainResource
  properties: {
    labels: eventGridDomainSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination: any(eventGridDomainSubscriptionEndpointType == 'AzureFunction' ? {
      endpointType: 'AzureFunction'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
      }
    } : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusQueue' ? {
      endpointType: 'ServiceBusQueue'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
      }
    } : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusTopic' ? {
      endpointType: 'ServiceBusTopic'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
      }
    } : any(eventGridDomainSubscriptionEndpointType == 'EventHub' ? {
      endpointType: 'EventHub'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridDomainSubscriptionEndpointName, '/')[0], split(eventGridDomainSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region)
      }
    } : any(eventGridDomainSubscriptionEndpointType == 'StorageQueue' ? {
      endpointType: 'StorageQueue'
      properties: {
        deliveryAttributeMappings: headers
        queueName: replace(last(split('${eventGridDomainSubscriptionEndpointName}', '/')), '@environment', environment)
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridDomainSubscriptionEndpointName, '/'))), '@environment', environment), '@region', region)
      }
    } : {})))))
    deadLetterDestination: !empty(eventGridDomainSubscriptionDeadLetterDestination) ? {
      endpointType: 'StorageBlob'
      properties: {
        deliveryAttributeMappings: headers
        blobContainerName: eventGridDomainSubscriptionDeadLetterDestination.storageAccountContainerName
        resourceId: replace(replace(az.resourceId(eventGridDomainSubscriptionDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDomainSubscriptionDeadLetterDestination.storageAccountName), '@environment', environment), '@region', region)
      }
    } : json('null')
    filter: any(empty(eventGridDomainSubscriptionEventTypes) ? {
      advancedFilters: eventGridDomainSubscriptionEventFilters
    } : {
      advancedFilters: eventGridDomainSubscriptionEventFilters
      includedEventTypes: eventGridDomainSubscriptionEventTypes
    })
  }
}

// 8. Return Deployment Output
output eventGridDomainSubscription object = eventGridDomainSubscriptionMsiEnabled == true ? azEventGridDomainWithMsiSubscriptionDeployment : azEventGridDomainWithoutMsiSubscriptionDeployment
