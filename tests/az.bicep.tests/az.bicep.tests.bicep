param environment string = 'dev'
param location string = 'est'
param resourceGroup object
param cosmosAccount object

targetScope = 'subscription'

module azResourceGroupDeploy '../../src/modules/az.resource.group/v1.0/az.resource.group.bicep' = {
  name: 'test-az-resource-group-deployment'
  params: {
    region: location
    environment: environment
    resourceGroupLocation: resourceGroup.resourceGroupLocation
    resourceGroupName: resourceGroup.resourceGroupName
  }
}

module azCosmosAccountDeploy '../../src/modules/az.cosmosdb.account/v1.0/az.cosmosdb.account.bicep' = {
  name: 'test-az-cosmos-account-deployment'
  scope: az.resourceGroup(azResourceGroupDeploy.name)
  params: {
    cosmosDbAccountName: cosmosAccount.cosmosAccountName
    cosmosDbAccountLocations: cosmosAccount.cosmosAccountLocations
  }
  dependsOn: [
    azResourceGroupDeploy
  ]
}
