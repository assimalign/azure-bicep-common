@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('')
param resourceGroupName string

@allowed([
  'eastus'
  'westus'
])
@description('')
param resourceGroupLocation string

param resourceGroupTags object = {}

targetScope = 'subscription'


resource azResourceGroupDeployment 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(replace(resourceGroupName, '@environment', environment), '@location', location)
  location: resourceGroupLocation
  tags: resourceGroupTags
}


output resource object = azResourceGroupDeployment
