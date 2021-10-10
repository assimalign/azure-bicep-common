@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('')
param eventGridDomainName string

@description('')
param eventGridEventTypes array = []

@description('')
param eventGridEventLabels array = []

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



// a. Get Event Grid Domain Resource
resource azEventGridDomainResource 'Microsoft.EventGrid/domains@2020-10-15-preview' existing = {
 name: replace('${eventGridDomainName}', '@environment', environment)
}

// 3. If applicable, get Service Bus Queue Resource
resource azServiceBusQueueResource 'Microsoft.ServiceBus/namespaces/queues@2021-01-01-preview' existing = if(eventGridSubscriptionEndpointType == 'ServiceBusQueue') {
  name: eventGridSubscriptionEndpointType == 'ServiceBusQueue' ? replace('${eventGridSubscriptionEndpointName}', '@environment', environment) : 'no-namespace/no-queue'
  scope: resourceGroup(replace('${eventGridSubscriptionEndpointResourceGroup}', '@environment', environment))
}

// 4. If applicable, get Service Bus Topic Resource
resource azServiceBusTopicResource 'Microsoft.ServiceBus/namespaces/topics@2021-01-01-preview' existing = if(eventGridSubscriptionEndpointType == 'ServiceBusTopic') {
  name: eventGridSubscriptionEndpointType == 'ServiceBusTopic' ? replace('${eventGridSubscriptionEndpointName}', '@environment', environment) : 'no-namespace/no-topic'
  scope: resourceGroup(replace('${eventGridSubscriptionEndpointResourceGroup}', '@environment', environment))
}

// 5. If applicable, get Event Hub Resource
resource azEventHubResource 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' existing = if(eventGridSubscriptionEndpointType == 'EventHub') {
  name: eventGridSubscriptionEndpointType == 'EventHub' ? replace('${eventGridSubscriptionEndpointName}', '@environment', environment) : 'no-namespace/no-event-hub'
  scope: resourceGroup(replace('${eventGridSubscriptionEndpointResourceGroup}', '@environment', environment))
}

// 6. If applicable, get Event Hub Resource
resource azEventGridFunctionAppResource 'Microsoft.Web/sites/functions@2021-01-01' existing = if(eventGridSubscriptionEndpointType == 'AzureFunction') {
  name: eventGridSubscriptionEndpointType == 'AzureFunction' ? replace('${eventGridSubscriptionEndpointName}', '@environment', environment) : 'no-function-app/no-function'
  scope: resourceGroup(replace('${eventGridSubscriptionEndpointResourceGroup}', '@environment', environment))
}

// 7. If applicable, get Event Hub Resource
resource azStorageAccountQueueResource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = if(eventGridSubscriptionEndpointType == 'StorageQueue') {
  name: eventGridSubscriptionEndpointType == 'StorageQueue' ? replace(toLower(replace(first(split('${eventGridSubscriptionEndpointName}', '/')), '-', '')), '@environment', environment): 'no-function-app/default/no-function'
  scope: resourceGroup(replace('${eventGridSubscriptionEndpointResourceGroup}', '@environment', environment))
}


// 
resource azEventGridDomainSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2020-10-15-preview' = {
  name: replace(eventGridSubscriptionName, '@environment', environment)
  scope: azEventGridDomainResource
  properties: {
   labels: eventGridEventLabels 
   eventDeliverySchema: 'EventGridSchema'
   deliveryWithResourceIdentity: {
     destination: any(eventGridSubscriptionEndpointType == 'ServiceBusQueue' ? {
        endpointType: eventGridSubscriptionEndpointType
        properties: {
          resourceId: azServiceBusQueueResource.id
        }
      } : any(eventGridSubscriptionEndpointType == 'ServiceBusTopic' ? {
        endpointType: eventGridSubscriptionEndpointType
        properties: {
          resourceId: azServiceBusTopicResource.id
        }
      } : any(eventGridSubscriptionEndpointType == 'EventHub' ? {
        endpointType: eventGridSubscriptionEndpointType
        properties: {
          resourceId: azEventHubResource.id
        }
      } : any(eventGridSubscriptionEndpointType == 'AzureFunction' ? {
        endpointType: eventGridSubscriptionEndpointType
        properties: {
          resourceId: azEventGridFunctionAppResource.id
        }
      } : any(eventGridSubscriptionEndpointType == 'StorageQueue' ? {
        endpointType: eventGridSubscriptionEndpointType
        properties: {
          queueName: replace(last(split('${eventGridSubscriptionEndpointName}', '/')), '@environment', environment)
          resourceId: azStorageAccountQueueResource.id
        }
      } : {})))))
      identity: {
        type:  'SystemAssigned'
      }
   }

   filter: any(empty(eventGridEventTypes) ? {
    advancedFilters: eventGridEventFilters
   } : {
    advancedFilters: eventGridEventFilters
    includedEventTypes: eventGridEventTypes
   })
  }
}
