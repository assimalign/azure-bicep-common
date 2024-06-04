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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var headers = [
  for header in eventGridDomainSubscriptionEventHeaders: {
    type: header.type
    name: header.name
    properties: any(header.type == 'Dynamic'
      ? {
          sourceField: header.value
        }
      : {
          value: header.value
          isSecret: false
        })
  }
]

// 1. Get Event Grid Domain Resource
resource azEventGridDomainResource 'Microsoft.EventGrid/domains@2022-06-15' existing = {
  name: formatName(eventGridDomainName, affix, environment, region)
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = if (eventGridDomainSubscriptionMsiEnabled == true) {
  name: eventGridDomainSubscriptionMsiEnabled == true
    ? formatName(eventGridDomainSubscriptionName, affix, environment, region)
    : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainResource
  properties: {
    labels: eventGridDomainSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridDomainSubscriptionEndpointType == 'AzureFunction'
        ? {
            endpointType: 'AzureFunction'
            properties: {
              deliveryAttributeMappings: headers
              resourceId: resourceId(
                formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                'Microsoft.Web/sites/functions',
                formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
              )
            }
          }
        : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusQueue'
            ? {
                endpointType: 'ServiceBusQueue'
                properties: {
                  deliveryAttributeMappings: headers
                  resourceId: resourceId(
                    formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                    'Microsoft.ServiceBus/namespaces/queues',
                    formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                    formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
                  )
                }
              }
            : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusTopic'
                ? {
                    endpointType: 'ServiceBusTopic'
                    properties: {
                      deliveryAttributeMappings: headers
                      resourceId: resourceId(
                        formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                        'Microsoft.ServiceBus/namespaces/topics',
                        formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                        formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
                      )
                    }
                  }
                : any(eventGridDomainSubscriptionEndpointType == 'EventHub'
                    ? {
                        endpointType: 'EventHub'
                        properties: {
                          deliveryAttributeMappings: headers
                          resourceId: resourceId(
                            formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                            'Microsoft.EventHub/namespaces/eventhubs',
                            formatName(
                              split(eventGridDomainSubscriptionEndpointName, '/')[0],
                              affix,
                              environment,
                              region
                            ),
                            formatName(
                              split(eventGridDomainSubscriptionEndpointName, '/')[1],
                              affix,
                              environment,
                              region
                            )
                          )
                        }
                      }
                    : any(eventGridDomainSubscriptionEndpointType == 'StorageQueue'
                        ? {
                            endpointType: 'StorageQueue'
                            properties: {
                              deliveryAttributeMappings: headers
                              queueName: formatName(
                                last(split('${eventGridDomainSubscriptionEndpointName}', '/')),
                                affix,
                                environment,
                                region
                              )
                              resourceId: resourceId(
                                formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                                'Microsoft.Storage/storageAccounts',
                                formatName(
                                  first(split(eventGridDomainSubscriptionEndpointName, '/')),
                                  affix,
                                  environment,
                                  region
                                )
                              )
                            }
                          }
                        : {})))))
      identity: {
        type: 'SystemAssigned'
      }
    }
    deadLetterWithResourceIdentity: !empty(eventGridDomainSubscriptionDeadLetterDestination)
      ? {
          deadLetterDestination: {
            endpointType: 'StorageBlob'
            properties: {
              blobContainerName: eventGridDomainSubscriptionDeadLetterDestination.storageAccountContainerName
              resourceId: resourceId(
                formatName(
                  eventGridDomainSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                  affix,
                  environment,
                  region
                ),
                'Microsoft.Storage/storageAccounts',
                formatName(
                  eventGridDomainSubscriptionDeadLetterDestination.storageAccountName,
                  affix,
                  environment,
                  region
                )
              )
            }
          }
          identity: {
            type: 'SystemAssigned'
          }
        }
      : null
    filter: any(empty(eventGridDomainSubscriptionEventTypes)
      ? {
          advancedFilters: eventGridDomainSubscriptionEventFilters
        }
      : {
          advancedFilters: eventGridDomainSubscriptionEventFilters
          includedEventTypes: eventGridDomainSubscriptionEventTypes
        })
  }
}

resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = if (eventGridDomainSubscriptionMsiEnabled == false) {
  name: eventGridDomainSubscriptionMsiEnabled == false
    ? formatName(eventGridDomainSubscriptionName, affix, environment, region)
    : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainResource
  properties: {
    labels: eventGridDomainSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination: any(eventGridDomainSubscriptionEndpointType == 'AzureFunction'
      ? {
          endpointType: 'AzureFunction'
          properties: {
            deliveryAttributeMappings: headers
            resourceId: resourceId(
              formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
              'Microsoft.Web/sites/functions',
              formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
              formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
            )
          }
        }
      : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusQueue'
          ? {
              endpointType: 'ServiceBusQueue'
              properties: {
                deliveryAttributeMappings: headers
                resourceId: resourceId(
                  formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                  'Microsoft.ServiceBus/namespaces/queues',
                  formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                  formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
                )
              }
            }
          : any(eventGridDomainSubscriptionEndpointType == 'ServiceBusTopic'
              ? {
                  endpointType: 'ServiceBusTopic'
                  properties: {
                    deliveryAttributeMappings: headers
                    resourceId: resourceId(
                      formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                      'Microsoft.ServiceBus/namespaces/topics',
                      formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                      formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
                    )
                  }
                }
              : any(eventGridDomainSubscriptionEndpointType == 'EventHub'
                  ? {
                      endpointType: 'EventHub'
                      properties: {
                        deliveryAttributeMappings: headers
                        resourceId: resourceId(
                          formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                          'Microsoft.EventHub/namespaces/eventhubs',
                          formatName(split(eventGridDomainSubscriptionEndpointName, '/')[0], affix, environment, region),
                          formatName(split(eventGridDomainSubscriptionEndpointName, '/')[1], affix, environment, region)
                        )
                      }
                    }
                  : any(eventGridDomainSubscriptionEndpointType == 'StorageQueue'
                      ? {
                          endpointType: 'StorageQueue'
                          properties: {
                            deliveryAttributeMappings: headers
                            queueName: formatName(
                              last(split('${eventGridDomainSubscriptionEndpointName}', '/')),
                              affix,
                              environment,
                              region
                            )
                            resourceId: resourceId(
                              formatName(eventGridDomainSubscriptionEndpointResourceGroup, affix, environment, region),
                              'Microsoft.Storage/storageAccounts',
                              formatName(
                                first(split(eventGridDomainSubscriptionEndpointName, '/')),
                                affix,
                                environment,
                                region
                              )
                            )
                          }
                        }
                      : {})))))
    deadLetterDestination: !empty(eventGridDomainSubscriptionDeadLetterDestination)
      ? {
          endpointType: 'StorageBlob'
          properties: {
            deliveryAttributeMappings: headers
            blobContainerName: eventGridDomainSubscriptionDeadLetterDestination.storageAccountContainerName
            resourceId: resourceId(
              formatName(
                eventGridDomainSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                affix,
                environment,
                region
              ),
              'Microsoft.Storage/storageAccounts',
              formatName(
                eventGridDomainSubscriptionDeadLetterDestination.storageAccountName,
                affix,
                environment,
                region
              )
            )
          }
        }
      : null
    filter: any(empty(eventGridDomainSubscriptionEventTypes)
      ? {
          advancedFilters: eventGridDomainSubscriptionEventFilters
        }
      : {
          advancedFilters: eventGridDomainSubscriptionEventFilters
          includedEventTypes: eventGridDomainSubscriptionEventTypes
        })
  }
}

// 8. Return Deployment Output
output eventGridDomainSubscription object = eventGridDomainSubscriptionMsiEnabled == true
  ? azEventGridDomainWithMsiSubscriptionDeployment
  : azEventGridDomainWithoutMsiSubscriptionDeployment
