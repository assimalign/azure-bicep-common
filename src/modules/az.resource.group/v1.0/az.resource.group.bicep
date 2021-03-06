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

@description('The name of the resource group.')
param resourceGroupName string

@allowed([
  'eastus'
  'eastus2'
  'westus'
  'westus2'
  'westus3'
  'westcentralus'
  'southcentralus'
  'northcentralus'
  'northeurope'
  'swedencentral'
  'uksouth'
  'ukwest'
  'westeurope'
  'francecentral'
  'germanywestcentral'
  'norwayeast'
  'switzerlandnorth'
])
@description('The location of the resource group')
param resourceGroupLocation string

@description('Custom metadata information to attach to the deployment.')
param resourceGroupTags object = {}

targetScope = 'subscription'

resource azResourceGroupDeployment 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(replace(resourceGroupName, '@environment', environment), '@region', region)
  location: resourceGroupLocation
  tags:  union(resourceGroupTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output resourceGroup object = azResourceGroupDeployment
