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

@description('The name of an existing Event Grid Domain Topic to deploy the new Subscription to')
param eventGridSystemTopicName string

@description('The name of the new Subscriptio to deploy')
param eventGridSystemTopicSubscriptionName string

@description('Custom tags for events being delivered to the subscription')
param eventGridSystemTopicSubscriptionEventTypes array = []

@description('Custom query for filtering event message to subscription')
param eventGridSystemTopicSubscriptionEventFilters array = []

@description('Custom labels to categorize the event grid subscriptions')
param eventGridSystemTopicSubscriptionEventLabels array = []

@description('Csstom HTTP headers to add the request to the subscription endpoint')
param eventGridSystemTopicSubscriptionEventHeaders array = []

@description('')
param eventGridSystemTopicSubscriptionEventSubjectFilters object = {}

@description('The storage account blob container to dead letter undeliverable event messages')
param eventGridSystemTopicSubscriptionDeadLetterDestination object = {}

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
param eventGridSystemTopicSubscriptionEndpointType string

@description('The name of the event grid handler')
param eventGridSystemTopicSubscriptionEndpointName string

@description('the name of the resource group the event event grid handler lives in')
param eventGridSystemTopicSubscriptionEndpointResourceGroup string

@description('')
param eventGridSystemTopicSubscriptionMsiEnabled bool = false

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var headers = [
  for header in eventGridSystemTopicSubscriptionEventHeaders: {
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

var subjectFilters = {
  subjectBeginsWith: contains(eventGridSystemTopicSubscriptionEventSubjectFilters, 'subjectBeginsWith')
    ? replace(
        replace(eventGridSystemTopicSubscriptionEventSubjectFilters.subjectBeginsWith, '@environment', environment),
        '@region',
        region
      )
    : null
  subjectEndsWith: contains(eventGridSystemTopicSubscriptionEventSubjectFilters, 'subjectEndsWith')
    ? replace(
        replace(eventGridSystemTopicSubscriptionEventSubjectFilters.subjectEndsWith, '@environment', environment),
        '@region',
        region
      )
    : null
  isSubjectCaseSensitive: contains(eventGridSystemTopicSubscriptionEventSubjectFilters, 'isSubjectCaseSensitive')
    ? eventGridSystemTopicSubscriptionEventSubjectFilters.isSubjectCaseSensitive
    : false
}
// 1. Get an Existing Event Grid Domain Resource
resource azEventGridDomainTopicResource 'Microsoft.EventGrid/systemTopics@2022-06-15' existing = {
  name: replace(replace(eventGridSystemTopicName, '@environment', environment), '@region', region)
  scope: resourceGroup()
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = if (eventGridSystemTopicSubscriptionMsiEnabled == true) {
  name: eventGridSystemTopicSubscriptionMsiEnabled == true
    ? replace(replace(eventGridSystemTopicSubscriptionName, '@environment', environment), '@region', region)
    : 'no-egd-subscription-with-msi'
  parent: azEventGridDomainTopicResource
  properties: {
    labels: eventGridSystemTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridSystemTopicSubscriptionEndpointType == 'AzureFunction'
        ? {
            endpointType: 'AzureFunction'
            properties: {
              deliveryAttributeMappings: headers
              resourceId: resourceId(
                formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                'Microsoft.Web/sites/functions',
                formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
              )
            }
          }
        : any(eventGridSystemTopicSubscriptionEndpointType == 'ServiceBusQueue'
            ? {
                endpointType: 'ServiceBusQueue'
                properties: {
                  deliveryAttributeMappings: headers
                  resourceId: resourceId(
                    formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                    'Microsoft.ServiceBus/namespaces/queues',
                    formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                    formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
                  )
                }
              }
            : any(eventGridSystemTopicSubscriptionEndpointType == 'ServiceBusTopic'
                ? {
                    endpointType: 'ServiceBusTopic'
                    properties: {
                      deliveryAttributeMappings: headers
                      resourceId: resourceId(
                        formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                        'Microsoft.ServiceBus/namespaces/topics',
                        formatName(
                          split(eventGridSystemTopicSubscriptionEndpointName, '/')[0],
                          affix,
                          environment,
                          region
                        ),
                        formatName(
                          split(eventGridSystemTopicSubscriptionEndpointName, '/')[1],
                          affix,
                          environment,
                          region
                        )
                      )
                    }
                  }
                : any(eventGridSystemTopicSubscriptionEndpointType == 'EventHub'
                    ? {
                        endpointType: 'EventHub'
                        properties: {
                          deliveryAttributeMappings: headers
                          resourceId: resourceId(
                            formatName(
                              eventGridSystemTopicSubscriptionEndpointResourceGroup,
                              affix,
                              environment,
                              region
                            ),
                            'Microsoft.EventHub/namespaces/eventhubs',
                            formatName(
                              split(eventGridSystemTopicSubscriptionEndpointName, '/')[0],
                              affix,
                              environment,
                              region
                            ),
                            formatName(
                              split(eventGridSystemTopicSubscriptionEndpointName, '/')[1],
                              affix,
                              environment,
                              region
                            )
                          )
                        }
                      }
                    : any(eventGridSystemTopicSubscriptionEndpointType == 'StorageQueue'
                        ? {
                            endpointType: 'StorageQueue'
                            properties: {
                              deliveryAttributeMappings: headers
                              queueName: formatName(
                                last(split('${eventGridSystemTopicSubscriptionEndpointName}', '/')),
                                affix,
                                environment,
                                region
                              )
                              resourceId: resourceId(
                                formatName(
                                  eventGridSystemTopicSubscriptionEndpointResourceGroup,
                                  affix,
                                  environment,
                                  region
                                ),
                                'Microsoft.Storage/storageAccounts',
                                formatName(
                                  first(split(eventGridSystemTopicSubscriptionEndpointName, '/')),
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
    deadLetterWithResourceIdentity: !empty(eventGridSystemTopicSubscriptionDeadLetterDestination)
      ? {
          deadLetterDestination: {
            endpointType: 'StorageBlob'
            properties: {
              blobContainerName: eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountContainerName
              resourceId: resourceId(
                formatName(
                  eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                  affix,
                  environment,
                  region
                ),
                'Microsoft.Storage/storageAccounts',
                formatName(
                  eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountName,
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
    filter: any(union(
      empty(eventGridSystemTopicSubscriptionEventTypes)
        ? {
            advancedFilters: eventGridSystemTopicSubscriptionEventFilters
          }
        : {
            advancedFilters: eventGridSystemTopicSubscriptionEventFilters
            includedEventTypes: eventGridSystemTopicSubscriptionEventTypes
          },
      subjectFilters
    ))
  }
}

resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = if (eventGridSystemTopicSubscriptionMsiEnabled == false) {
  name: eventGridSystemTopicSubscriptionMsiEnabled == false
    ? replace(replace(eventGridSystemTopicSubscriptionName, '@environment', environment), '@region', region)
    : 'no-egd-subscription-without-msi'
  parent: azEventGridDomainTopicResource
  properties: {
    labels: eventGridSystemTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination: any(eventGridSystemTopicSubscriptionEndpointType == 'AzureFunction'
      ? {
          endpointType: 'AzureFunction'
          properties: {
            deliveryAttributeMappings: headers
            resourceId: resourceId(
              formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
              'Microsoft.Web/sites/functions',
              formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
              formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
            )
          }
        }
      : any(eventGridSystemTopicSubscriptionEndpointType == 'ServiceBusQueue'
          ? {
              endpointType: 'ServiceBusQueue'
              properties: {
                deliveryAttributeMappings: headers
                resourceId: resourceId(
                  formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                  'Microsoft.ServiceBus/namespaces/queues',
                  formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                  formatName(split(eventGridSystemTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
                )
              }
            }
          : any(eventGridSystemTopicSubscriptionEndpointType == 'ServiceBusTopic'
              ? {
                  endpointType: 'ServiceBusTopic'
                  properties: {
                    deliveryAttributeMappings: headers
                    resourceId: resourceId(
                      formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                      'Microsoft.ServiceBus/namespaces/topics',
                      formatName(
                        split(eventGridSystemTopicSubscriptionEndpointName, '/')[0],
                        affix,
                        environment,
                        region
                      ),
                      formatName(
                        split(eventGridSystemTopicSubscriptionEndpointName, '/')[1],
                        affix,
                        environment,
                        region
                      )
                    )
                  }
                }
              : any(eventGridSystemTopicSubscriptionEndpointType == 'EventHub'
                  ? {
                      endpointType: 'EventHub'
                      properties: {
                        deliveryAttributeMappings: headers
                        resourceId: resourceId(
                          formatName(eventGridSystemTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                          'Microsoft.EventHub/namespaces/eventhubs',
                          formatName(
                            split(eventGridSystemTopicSubscriptionEndpointName, '/')[0],
                            affix,
                            environment,
                            region
                          ),
                          formatName(
                            split(eventGridSystemTopicSubscriptionEndpointName, '/')[1],
                            affix,
                            environment,
                            region
                          )
                        )
                      }
                    }
                  : any(eventGridSystemTopicSubscriptionEndpointType == 'StorageQueue'
                      ? {
                          endpointType: 'StorageQueue'
                          properties: {
                            deliveryAttributeMappings: headers
                            queueName: formatName(
                              last(split('${eventGridSystemTopicSubscriptionEndpointName}', '/')),
                              affix,
                              environment,
                              region
                            )
                            resourceId: resourceId(
                              formatName(
                                eventGridSystemTopicSubscriptionEndpointResourceGroup,
                                affix,
                                environment,
                                region
                              ),
                              'Microsoft.Storage/storageAccounts',
                              formatName(
                                first(split(eventGridSystemTopicSubscriptionEndpointName, '/')),
                                affix,
                                environment,
                                region
                              )
                            )
                          }
                        }
                      : {})))))
    deadLetterDestination: !empty(eventGridSystemTopicSubscriptionDeadLetterDestination)
    ? {
        endpointType: 'StorageBlob'
        properties: {
          deliveryAttributeMappings: headers
          blobContainerName: eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountContainerName
          resourceId: resourceId(
                eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                'Microsoft.Storage/storageAccounts',
                eventGridSystemTopicSubscriptionDeadLetterDestination.storageAccountName
              )
        }
      }
    : null
    filter: any(union(
      empty(eventGridSystemTopicSubscriptionEventTypes)
        ? {
            advancedFilters: eventGridSystemTopicSubscriptionEventFilters
          }
        : {
            advancedFilters: eventGridSystemTopicSubscriptionEventFilters
            includedEventTypes: eventGridSystemTopicSubscriptionEventTypes
          },
      subjectFilters
    ))
  }
}

// 8. Return Deployment Output
output eventGridSystemTopicSubscription object = eventGridSystemTopicSubscriptionMsiEnabled == true
  ? azEventGridDomainWithMsiSubscriptionDeployment
  : azEventGridDomainWithoutMsiSubscriptionDeployment
