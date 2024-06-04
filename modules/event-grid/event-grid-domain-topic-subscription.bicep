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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var headers = [
  for header in eventGridDomainTopicSubscriptionEventHeaders: {
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
  subjectBeginsWith: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'subjectBeginsWith')
    ? formatName(eventGridDomainTopicSubscriptionEventSubjectFilters.subjectBeginsWith, affix, environment, region)
    : null
  subjectEndsWith: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'subjectEndsWith')
    ? formatName(eventGridDomainTopicSubscriptionEventSubjectFilters.subjectEndsWith, affix, environment, region)
    : null
  isSubjectCaseSensitive: contains(eventGridDomainTopicSubscriptionEventSubjectFilters, 'isSubjectCaseSensitive')
    ? eventGridDomainTopicSubscriptionEventSubjectFilters.isSubjectCaseSensitive
    : false
}

// 1. Get an Existing Event Grid Domain Resource
resource azEventGridDomainTopicResource 'Microsoft.EventGrid/domains/topics@2022-06-15' existing = {
  name: formatName('${eventGridDomainName}/${eventGridDomainTopicName}', affix, environment, region)
  scope: resourceGroup()
}

// 2. Deploy the Event Grid Subscription to the Event Grid Domain Topic
resource azEventGridDomainWithMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = if (eventGridDomainTopicSubscriptionMsiEnabled == true) {
  name: eventGridDomainTopicSubscriptionMsiEnabled == true
    ? formatName(eventGridDomainTopicSubscriptionName, affix, environment, region)
    : 'no-egd-subscription-with-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridDomainTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    deliveryWithResourceIdentity: {
      destination: any(eventGridDomainTopicSubscriptionEndpointType == 'AzureFunction'
        ? {
            endpointType: 'AzureFunction'
            properties: {
              deliveryAttributeMappings: headers
              resourceId: resourceId(
                formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                'Microsoft.Web/sites/functions',
                formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
              )
            }
          }
        : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusQueue'
            ? {
                endpointType: 'ServiceBusQueue'
                properties: {
                  deliveryAttributeMappings: headers
                  resourceId: resourceId(
                    formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                    'Microsoft.ServiceBus/namespaces/queues',
                    formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                    formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
                  )
                }
              }
            : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusTopic'
                ? {
                    endpointType: 'ServiceBusTopic'
                    properties: {
                      deliveryAttributeMappings: headers
                      resourceId: resourceId(
                        formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                        'Microsoft.ServiceBus/namespaces/topics',
                        formatName(
                          split(eventGridDomainTopicSubscriptionEndpointName, '/')[0],
                          affix,
                          environment,
                          region
                        ),
                        formatName(
                          split(eventGridDomainTopicSubscriptionEndpointName, '/')[1],
                          affix,
                          environment,
                          region
                        )
                      )
                    }
                  }
                : any(eventGridDomainTopicSubscriptionEndpointType == 'EventHub'
                    ? {
                        endpointType: 'EventHub'
                        properties: {
                          deliveryAttributeMappings: headers
                          resourceId: resourceId(
                            formatName(
                              eventGridDomainTopicSubscriptionEndpointResourceGroup,
                              affix,
                              environment,
                              region
                            ),
                            'Microsoft.EventHub/namespaces/eventhubs',
                            formatName(
                              split(eventGridDomainTopicSubscriptionEndpointName, '/')[0],
                              affix,
                              environment,
                              region
                            ),
                            formatName(
                              split(eventGridDomainTopicSubscriptionEndpointName, '/')[1],
                              affix,
                              environment,
                              region
                            )
                          )
                        }
                      }
                    : any(eventGridDomainTopicSubscriptionEndpointType == 'StorageQueue'
                        ? {
                            endpointType: 'StorageQueue'
                            properties: {
                              deliveryAttributeMappings: headers
                              queueName: formatName(
                                last(split('${eventGridDomainTopicSubscriptionEndpointName}', '/')),
                                affix,
                                environment,
                                region
                              )
                              resourceId: resourceId(
                                formatName(
                                  eventGridDomainTopicSubscriptionEndpointResourceGroup,
                                  affix,
                                  environment,
                                  region
                                ),
                                'Microsoft.Storage/storageAccounts',
                                formatName(
                                  first(split(eventGridDomainTopicSubscriptionEndpointName, '/')),
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
    deadLetterWithResourceIdentity: !empty(eventGridDomainTopicSubscriptionDeadLetterDestination)
      ? {
          deadLetterDestination: {
            endpointType: 'StorageBlob'
            properties: {
              blobContainerName: eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountContainerName
              resourceId: resourceId(
                formatName(
                  eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                  affix,
                  environment,
                  region
                ),
                'Microsoft.Storage/storageAccounts',
                formatName(
                  eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountName,
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
      empty(eventGridDomainTopicSubscriptionEventTypes)
        ? {
            advancedFilters: eventGridDomainTopicSubscriptionEventFilters
          }
        : {
            advancedFilters: eventGridDomainTopicSubscriptionEventFilters
            includedEventTypes: eventGridDomainTopicSubscriptionEventTypes
          },
      subjectFilters
    ))
  }
}

resource azEventGridDomainWithoutMsiSubscriptionDeployment 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = if (eventGridDomainTopicSubscriptionMsiEnabled == false) {
  name: eventGridDomainTopicSubscriptionMsiEnabled == false
    ? formatName(eventGridDomainTopicSubscriptionName, affix, environment, region)
    : 'no-egd-subscription-without-msi'
  scope: azEventGridDomainTopicResource
  properties: {
    labels: eventGridDomainTopicSubscriptionEventLabels
    eventDeliverySchema: 'EventGridSchema'
    destination: any(eventGridDomainTopicSubscriptionEndpointType == 'AzureFunction'
      ? {
          endpointType: 'AzureFunction'
          properties: {
            deliveryAttributeMappings: headers
            resourceId: resourceId(
              formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
              'Microsoft.Web/sites/functions',
              formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
              formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
            )
          }
        }
      : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusQueue'
          ? {
              endpointType: 'ServiceBusQueue'
              properties: {
                deliveryAttributeMappings: headers
                resourceId: resourceId(
                  formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                  'Microsoft.ServiceBus/namespaces/queues',
                  formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[0], affix, environment, region),
                  formatName(split(eventGridDomainTopicSubscriptionEndpointName, '/')[1], affix, environment, region)
                )
              }
            }
          : any(eventGridDomainTopicSubscriptionEndpointType == 'ServiceBusTopic'
              ? {
                  endpointType: 'ServiceBusTopic'
                  properties: {
                    deliveryAttributeMappings: headers
                    resourceId: resourceId(
                      formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                      'Microsoft.ServiceBus/namespaces/topics',
                      formatName(
                        split(eventGridDomainTopicSubscriptionEndpointName, '/')[0],
                        affix,
                        environment,
                        region
                      ),
                      formatName(
                        split(eventGridDomainTopicSubscriptionEndpointName, '/')[1],
                        affix,
                        environment,
                        region
                      )
                    )
                  }
                }
              : any(eventGridDomainTopicSubscriptionEndpointType == 'EventHub'
                  ? {
                      endpointType: 'EventHub'
                      properties: {
                        deliveryAttributeMappings: headers
                        resourceId: resourceId(
                          formatName(eventGridDomainTopicSubscriptionEndpointResourceGroup, affix, environment, region),
                          'Microsoft.EventHub/namespaces/eventhubs',
                          formatName(
                            split(eventGridDomainTopicSubscriptionEndpointName, '/')[0],
                            affix,
                            environment,
                            region
                          ),
                          formatName(
                            split(eventGridDomainTopicSubscriptionEndpointName, '/')[1],
                            affix,
                            environment,
                            region
                          )
                        )
                      }
                    }
                  : any(eventGridDomainTopicSubscriptionEndpointType == 'StorageQueue'
                      ? {
                          endpointType: 'StorageQueue'
                          properties: {
                            deliveryAttributeMappings: headers
                            queueName: formatName(
                              last(split('${eventGridDomainTopicSubscriptionEndpointName}', '/')),
                              affix,
                              environment,
                              region
                            )
                            resourceId: resourceId(
                              formatName(
                                eventGridDomainTopicSubscriptionEndpointResourceGroup,
                                affix,
                                environment,
                                region
                              ),
                              'Microsoft.Storage/storageAccounts',
                              formatName(
                                first(split(eventGridDomainTopicSubscriptionEndpointName, '/')),
                                affix,
                                environment,
                                region
                              )
                            )
                          }
                        }
                      : {})))))
    deadLetterDestination: !empty(eventGridDomainTopicSubscriptionDeadLetterDestination)
      ? {
          endpointType: 'StorageBlob'
          properties: {
            deliveryAttributeMappings: headers
            blobContainerName: eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountContainerName
            resourceId: resourceId(
              formatName(
                eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountResourceGroupName,
                affix,
                environment,
                region
              ),
              'Microsoft.Storage/storageAccounts',
              formatName(
                eventGridDomainTopicSubscriptionDeadLetterDestination.storageAccountName,
                affix,
                environment,
                region
              )
            )
          }
        }
      : null
    filter: any(union(
      empty(eventGridDomainTopicSubscriptionEventTypes)
        ? {
            advancedFilters: eventGridDomainTopicSubscriptionEventFilters
          }
        : {
            advancedFilters: eventGridDomainTopicSubscriptionEventFilters
            includedEventTypes: eventGridDomainTopicSubscriptionEventTypes
          },
      subjectFilters
    ))
  }
}

// 8. Return Deployment Output
output eventGridDomainTopicSubscription object = eventGridDomainTopicSubscriptionMsiEnabled == true
  ? azEventGridDomainWithMsiSubscriptionDeployment
  : azEventGridDomainWithoutMsiSubscriptionDeployment
