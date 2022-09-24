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

@description('The name of an existing Event Grid Domain to deploy the new Subscription to')
param eventGridDomainName string

@description('The name of an existing Event Grid Domain Topic to deploy the new Subscription to')
param eventGridDomainTopicName string

@description('The name of the new Subscriptio to deploy')
param eventGridDomainTopicSubscriptionName string

@description('Custom tags for events being delivered to the subscription')
param eventGridDomainTopicSubscriptionEventTypes array = []

@description('Custom query for filtering event message to subscription')
param eventGridDomainTopicSubscriptionEventFilters array = []

@description('Custom labels to categorize the event grid subscriptions')
param eventGridDomainTopicSubscriptionEventLabels array = []

@description('')
param eventGridDomainTopicSubscriptionEventSubjectFilters object = {}

@description('Csstom HTTP headers to add the request to the subscription endpoint')
param eventGridDomainTopicSubscriptionEventHeaders array = []

@description('The storage account blob container to dead letter undeliverable event messages')
param eventGridDomainTopicSubscriptionDeadLetterDestination object = {}

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
param eventGridDomainTopicSubscriptionEndpointType string

@description('The name of the event grid handler')
param eventGridDomainTopicSubscriptionEndpointName string

@description('the name of the resource group the event event grid handler lives in')
param eventGridDomainTopicSubscriptionEndpointResourceGroup string

@description('')
param eventGridDomainTopicSubscriptionMsiEnabled bool = false

var headers = [for header in eventGridDomainTopicSubscriptionEventHeaders: {
  type: header.type
  name: header.name
  properties: any(header.type == 'Dynamic' ? {
    sourceField: header.value
  } : {
    value: header.value
    isSecret: false
  })
}]

var subjectFilters = {
  subjectBeginsWith: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'subjectBeginsWith') ? replace(replace(eventGridDomainTopicSubscriptionEventSubjectFilters.subjectBeginsWith, '@environment', environment), '@region', region) : json('null')
  subjectEndsWith: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'subjectEndsWith') ? replace(replace(eventGridDomainTopicSubscriptionEventSubjectFilters.subjectEndsWith, '@environment', environment), '@region', region) : json('null')
  isSubjectCaseSensitive: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'isSubjectCaseSensitive') ? eventGridDomainTopicSubscriptionEventSubjectFilters.isSubjectCaseSensitive : false
}

// 1. Get an Existing Event Grid Domain Resource
resource azEventGridDomainTopicResource 'Microsoft.EventGrid/domains/topics@2021-06-01-preview' existing = {
  name: replace(replace('${eventGridDomainName}/${eventGridDomainTopicName}', '@environment', environment), '@region', region)
  scope: resourceGroup()
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if (eventGridDomainTopicSubscriptionMsiEnabled == true) {
  name: eventGridDomainTopicSubscriptionMsiEnabled == true ? replace(replace(eventGridDomainTopicSubscriptionName, '@environment', environment), '@region', region) : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridDomainTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridDomainTopicSubscriptionEndpointType == 'AzureFunction' ? {
        endpointType: 'AzureFunction'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
        }
      } : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusQueue' ? {
        endpointType: 'ServiceBusQueue'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
        }
      } : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusTopic' ? {
        endpointType: 'ServiceBusTopic'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
        }
      } : any(eventGridDomainTopicSubscriptionEndpointType == 'EventHub' ? {
        endpointType: 'EventHub'
        properties: {
          deliveryAttributeMappings: headers
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
        }
      } : any(eventGridDomainTopicSubscriptionEndpointType == 'StorageQueue' ? {
        endpointType: 'StorageQueue'
        properties: {
          deliveryAttributeMappings: headers
          queueName: replace(last(split('${eventGridDomainTopicSubscriptionEndpointName}', '/')), '@environment', environment)
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridDomainTopicSubscriptionEndpointName, '/'))), '@environment', environment), '@region', region))
        }
      } : {})))))
      identity: {
        type: 'SystemAssigned'
      }
    }
    deadLetterWithResourceIdentity: !empty(eventGridDomainTopicSubscriptionDeadLetterDestination) ? {
      deadLetterDestination: {
        endpointType: 'StorageBlob'
        properties: {
          blobContainerName: eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountContainerName
          resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountName), '@environment', environment), '@region', region))
        }
      }
      identity: {
        type: 'SystemAssigned'
      }
    } : json('null')
    filter: any(union(empty(eventGridDomainTopicSubscriptionEventTypes) ? {
        advancedFilters: eventGridDomainTopicSubscriptionEventFilters
      } : {
        advancedFilters: eventGridDomainTopicSubscriptionEventFilters
        includedEventTypes: eventGridDomainTopicSubscriptionEventTypes
      }, subjectFilters))
  }
}

resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2021-06-01-preview' = if (eventGridDomainTopicSubscriptionMsiEnabled == false) {
  name: eventGridDomainTopicSubscriptionMsiEnabled == false ? replace(replace(eventGridDomainTopicSubscriptionName, '@environment', environment), '@region', region) : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridDomainTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination: any(eventGridDomainTopicSubscriptionEndpointType == 'AzureFunction' ? {
      endpointType: 'AzureFunction'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.Web/sites/functions', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
      }
    } : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusQueue' ? {
      endpointType: 'ServiceBusQueue'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/queues', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
      }
    } : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusTopic' ? {
      endpointType: 'ServiceBusTopic'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.ServiceBus/namespaces/topics', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
      }
    } : any(eventGridDomainTopicSubscriptionEndpointType == 'EventHub' ? {
      endpointType: 'EventHub'
      properties: {
        deliveryAttributeMappings: headers
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.EventHub/namespaces/eventhubs', split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], split(eventGridDomainTopicSubscriptionEndpointName, '/')[1]), '@environment', environment), '@region', region))
      }
    } : any(eventGridDomainTopicSubscriptionEndpointType == 'StorageQueue' ? {
      endpointType: 'StorageQueue'
      properties: {
        deliveryAttributeMappings: headers
        queueName: replace(last(split('${eventGridDomainTopicSubscriptionEndpointName}', '/')), '@environment', environment)
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionEndpointResourceGroup, 'Microsoft.Storage/storageAccounts', first(split(eventGridDomainTopicSubscriptionEndpointName, '/'))), '@environment', environment), '@region', region))
      }
    } : {})))))
    deadLetterDestination: !empty(eventGridDomainTopicSubscriptionDeadLetterDestination) ? {
      endpointType: 'StorageBlob'
      properties: {
        deliveryAttributeMappings: headers
        blobContainerName: eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountContainerName
        resourceId: any(replace(replace(az.resourceId(eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountName), '@environment', environment), '@region', region))
      }
    } : json('null')
    filter: any(union(empty(eventGridDomainTopicSubscriptionEventTypes) ? {
        advancedFilters: eventGridDomainTopicSubscriptionEventFilters
      } : {
        advancedFilters: eventGridDomainTopicSubscriptionEventFilters
        includedEventTypes: eventGridDomainTopicSubscriptionEventTypes
      }, subjectFilters))
  }
}

// 8. Return Deployment Output
output eventGridDomainTopicSubscription object = eventGridDomainTopicSubscriptionMsiEnabled == true ? azEventGridDomainWithMsiSubscriptionDeployment : azEventGridDomainWithoutMsiSubscriptionDeployment
