param environment string = 'dev'
param location string = 'est'
param resourceGroup object
param cosmosAccount object
param cosmosAccountsDocumentDatabase object
param cosmosAccountsDocumentDatabaseContainer object

targetScope = 'subscription'

module azResourceGroupDeploy '../../src/modules/az.resource.group/v1.0/az.resource.group.bicep' = {
  name: 'test-az-resource-group-deployment'
  params: {
    affix: affix
    region: location
    environment: environment
    resourceGroupLocation: resourceGroup.resourceGroupLocation
    resourceGroupName: resourceGroup.resourceGroupName
  }
}

module azCosmosAccountDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.bicep' = {
  name: 'test-az-cosmos-account-deploy'
  scope: az.resourceGroup(replace(replace(cosmosAccount.cosmosAccountResourceGroup, '@environment', environment), '@region', location))
  params: {
    affix: affix
    region: location
    environment: environment
    cosmosDbAccountName: cosmosAccount.cosmosAccountName
    cosmosDbAccountLocations: cosmosAccount.cosmosAccountLocations
    cosmosDbAccountDatabases: cosmosAccount.cosmosAccountDatabases
  }
  dependsOn: [
    azResourceGroupDeploy
  ]
}

module azCosmosAccountDatabaseDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.document.database.bicep' = {
  name: 'test-az-cosmos-database-deploy'
  scope: az.resourceGroup(replace(replace(cosmosAccountsDocumentDatabase.cosmosAccountResourceGroup, '@environment', environment), '@region', location))
  params: {
    region: location
    environment: environment
    cosmosDbAccountName: cosmosAccountsDocumentDatabase.cosmosAccountName
    cosmosDbAccountDatabaseName: cosmosAccountsDocumentDatabase.cosmosDatabaseName
  }
  dependsOn: [
    azCosmosAccountDeploy
  ]
}

module azCosmosAccountDatabasteContainerDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.document.database.container.bicep' = {
  name: 'test-az-cosmos-database-container-deploy'
  scope: az.resourceGroup(replace(replace(cosmosAccountsDocumentDatabaseContainer.cosmosAccountResourceGroup, '@environment', environment), '@region', location))
  params: {
    region: location
    environment: environment
    cosmosDbAccountName: cosmosAccountsDocumentDatabaseContainer.cosmosAccountName
    cosmosDbAccountDatabaseName: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseName
    cosmosDbAccountDatabaseContainerName: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseContainerName
    cosmosDbAccountDatabaseContainerPartition: cosmosAccountsDocumentDatabaseContainer.cosmosDatabaseContainerPartitionKey
  }
  dependsOn: [
    azCosmosAccountDeploy
  ]
}
