param environment string = 'dev'
param location string = 'est'
param resourceGroup object
param cosmosAccount object
param cosmosAccountsDocumentDatabase object
param cosmosAccountsDocumentDatabaseContainer object
param eventGridDomain object
param serviceBusNamespace object
param serviceBusNamespaceQueue object
param serviceBusNamespaceTopic object
param cognitiveSearchService object
param storageAccount object
param dataShareAccount object

targetScope = 'subscription'

var cosmosResourceGroup = az.resourceGroup(replace(replace(cosmosAccount.cosmosAccountResourceGroup, '@environment', environment), '@region', location))

// module azResourceGroupDeploy '../../src/modules/az.resource.group/v1.0/az.resource.group.bicep' = {
//   name: 'test-az-resource-group-deployment'
//   params: {
//     region: location
//     environment: environment
//     resourceGroupLocation: resourceGroup.resourceGroupLocation
//     resourceGroupName: resourceGroup.resourceGroupName
//   }
// }

// module azCosmosAccountDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.bicep' = {
//   name: 'test-az-cosmos-account-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     cosmosDbAccountName: cosmosAccount.cosmosAccountName
//     cosmosDbAccountLocations: cosmosAccount.cosmosAccountLocations
//     cosmosDbAccountDatabases: cosmosAccount.cosmosAccountDatabases
//   }
//   dependsOn: [
//     azResourceGroupDeploy
//   ]
// }

// module azCosmosAccountDatabaseDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.document.database.bicep' = {
//   name: 'test-az-cosmos-database-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     cosmosDbAccountName: cosmosAccountsDocumentDatabase.cosmosAccountName
//     cosmosDbAccountDatabaseName: cosmosAccountsDocumentDatabase.cosmosDatabaseName
//   }
//   dependsOn: [
//     azCosmosAccountDeploy
//   ]
// }

// module azCosmosAccountDatabasteContainerDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.document.database.container.bicep' = {
//   name: 'test-az-cosmos-database-container-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     cosmosDbAccountName: cosmosAccountsDocumentDatabaseContainer.cosmosAccountName
//     cosmosDbAccountDatabaseName: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseName
//     cosmosDbAccountDatabaseContainerName: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseContainerName
//     cosmosDbAccountDatabaseContainerPartition: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseContainerPartitionKey
//   }
//   dependsOn: [
//     azCosmosAccountDeploy
//   ]
// }

// module azServiceBusDeploy '../../src/modules/az.service.bus/v1.0/az.service.bus.namespace.bicep' = {
//   name: 'test-az-sb-namespace-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     serviceBusName: serviceBusNamespace.serviceBusName
//     serviceBusLocation: serviceBusNamespace.serviceBusLocation
//     serviceBusSku: serviceBusNamespace.serviceBusSku
//     serviceBusTopics: serviceBusNamespace.serviceBusTopics
//     serviceBusQueues:serviceBusNamespace.serviceBusQueues
//   }
// }

// module azServiceBusQueueDeploy '../../src/modules/az.service.bus/v1.0/az.service.bus.namespace.queue.bicep' = {
//   name: 'test-az-sb-namespace-queue-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     serviceBusName: serviceBusNamespaceQueue.serviceBusName
//     serviceBusQueueName: serviceBusNamespaceQueue.serviceBusQueueName
//   }
//   dependsOn: [
//     azServiceBusDeploy
//   ]
// }

// module azServiceBusTopicDeploy '../../src/modules/az.service.bus/v1.0/az.service.bus.namespace.topic.bicep' = {
//   name: 'test-az-sb-namespace-topic-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     serviceBusName: serviceBusNamespaceTopic.serviceBusName
//     serviceBusTopicName: serviceBusNamespaceTopic.serviceBusTopicName
//   }
//   dependsOn: [
//     azServiceBusDeploy
//   ]
// }

// module azEventGridDeploy '../../src/modules/az.event.grid/v1.0/az.event.grid.domain.bicep' ={
//   name: 'test-az-eg-domain-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     eventGridDomainName: eventGridDomain.eventGridDomainName
//     eventGridDomainLocation: eventGridDomain.eventGridDomainLocation
//   }
// }

// module azCognitiveSearchDeploy '../../src/modules/az.cognitive.search/v1.0/az.cognitive.search.account.bicep' = {
//   name: 'test-az-cog-search-deploy'
//   scope: cosmosResourceGroup
//   params: {
//     region: location
//     environment: environment
//     cognitiveSearchName: cognitiveSearchService.cognitiveSearchName
//     cognitiveSearchLocation: cognitiveSearchService.cognitiveSearchLocation
//   }
// }

module azDataShareDeployment '../../src/modules/az.data.share.account/v1.0/az.data.share.account.bicep' = {
  name: 'test-az-data-share-deploy'
  scope: cosmosResourceGroup
  params: {
    region: location
    environment: environment
    dataShareAccountName: dataShareAccount.dataShareAccountName
    dataShareAccountLocation: dataShareAccount.dataShareAccountLocation
  }
}
