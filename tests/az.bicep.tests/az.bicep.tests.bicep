param environment string = 'dev'
param location string = 'est'
param resourceGroup object

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
