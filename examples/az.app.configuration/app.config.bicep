param resourceGroups array
param appConfigurations array

targetScope = 'subscription'

module azResourceGroupDeployment 'br/assimalign:modules/az.resource.group:v1.0' = [for group in resourceGroups: {
  name: 'az-rg-deploy-${guid(group.resourceGroupName)}'
  params: {
    region: 'est'
    environment: 'dev'
    resourceGroupName: group.resourceGroupName
    resourceGroupLocation: group.resourceGroupLocation
    resourceGroupTags: contains(group, 'resourceGroupTags') ? group.resourceGroupTags : {}
  }
}]

module azAppConfigurationDeployment 'br/assimalign:modules/az.app.configuration:v1.0' = [for config in appConfigurations: {
  name: 'az-app-cfg-deploy'
  scope: resourceGroup(replace(replace(config.appConfigurationResourceGroup, '@environment', 'dev'), '@region', 'est'))
  params: {
    region: 'est'
    environment: 'dev'
    appConfigurationName: config.appConfigurationName
    appConfigurationSku: config.appConfigurationSku
    appConfigurationDisablePublicAccess: config.appConfigurationDisablePublicAccess
    appConfigurationEnableMsi: config.appConfigurationEnableMsi
    appConfigurationEnableRbac: config.appConfigurationEnableRbac
    appConfigurationKeys: config.appConfigurationKeys
    appConfigurationTags: config.appConfigurationTags
  }
  dependsOn: [
    azResourceGroupDeployment
  ]
}]


//az deployment sub create --location 'eastus' --name 'asal-app-config-test' --template-file './examples/az.app.configuration/app.config.bicep' --parameters './examples/az.app.configuration/app.config.params.json' --debug --verbose
