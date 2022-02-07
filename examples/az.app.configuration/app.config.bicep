param resourceGroups array
param appConfigurations array

targetScope = 'subscription'

module azResourceGroupDeployment '../../src/modules/az.resource.group.bicep' = [for group in resourceGroups: {
  name: 'az-rg-deploy-${guid(group.resourceGroupName)}'
  params: {
    location: 'est'
    environment: 'dev'
    resourceGroupName: group.resourceGroupName
    resourceGroupLocation: group.resourceGroupLocation
    resourceGroupTags: contains(group, 'resourceGroupTags') ? group.resourceGroupTags : {}
  }
}]

module azAppConfigurationDeployment '../../src/modules/az.app.configuration.bicep' = [for config in appConfigurations: {
  name: 'az-'
  scope: resourceGroup(replace(replace(config.appConfigurationResourceGroup, '@environment', 'dev'), '@location', 'est'))
  params: {
    location: 'est'
    environment: 'dev'
    appConfigurationName: config.appConfigurationName
    appConfigurationSku: config.appConfigurationSku
    appConfigurationDisablePublicAccess: config.appConfigurationDisablePublicAccess
    appConfigurationEnableMsi: config.appConfigurationEnableMsi
    appConfigurationEnableRbac: config.appConfigurationEnableRbac
    appConfigurationKeys: config.appConfigurationKeys
  }
  dependsOn: [
    azResourceGroupDeployment
  ]
}]


//az deployment sub create --location 'eastus' --name 'asal-app-config-test' --template-file './examples/az.app.configuration/app.config.bicep' --parameters './examples/az.app.configuration/app.config.params.json' --debug --verbose
