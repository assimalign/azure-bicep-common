@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of the app configuration')
param appConfigurationName string

@description('The region/location the Azure App Configuration instance will be deployed to.')
param appConfigurationLocation string = resourceGroup().location

@description('The pricing tier for Azure App Configurations: "Free" or "Standard". Default is "Free"')
param appConfigurationSku object

@description('An array of object containing the key, value, and contentType if applicable.')
param appConfigurationKeys array = []

@description('Private endpoint configuration for the app configuration deployment')
param appConfigurationPrivateEndpoint object = {}

@description('Enables Managed System Identity')
param appConfigurationEnableMsi bool = false

@description('Disables public network access to the resource')
param appConfigurationDisablePublicAccess bool = true

@description('Enables RBAC over access policies')
param appConfigurationEnableRbac bool = false

@description('The tags to attach to the resource when deployed')
param appConfigurationTags object = {}

// **************************************************************************************** //
//                          Azure App Configuration Deployment                              //
// **************************************************************************************** //

var appConfigSku = any((environment == 'dev') ? {
  name: appConfigurationSku.dev
} : any((environment == 'qa') ? {
  name: appConfigurationSku.qa
} : any((environment == 'uat') ? {
  name: appConfigurationSku.uat
} : any((environment == 'prd') ? {
  name: appConfigurationSku.prd
} : {
  name: 'Free'
}))))

// 1. Deploys a single instance of Azure App Configuration
resource azAppConfigurationDeployment 'Microsoft.AppConfiguration/configurationStores@2021-03-01-preview' = {
  name: replace(replace(appConfigurationName, '@environment', environment), '@region', region)
  location: appConfigurationLocation
  sku: appConfigSku
  identity: {
    type: appConfigurationEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    disableLocalAuth: appConfigurationEnableRbac
    publicNetworkAccess: appConfigurationDisablePublicAccess == true ? 'Disabled' : 'Enabled'
  }
  tags: appConfigurationTags
}

// 2. Deploy any Azure App Configuration Keys and values
module azAppConfigurationKeysDeployement 'az.app.configuration.key.bicep' = [for key in appConfigurationKeys: if (!empty(appConfigurationKeys) && appConfigurationEnableRbac == false) {
  name: 'az-app-cfg-key-${guid('${azAppConfigurationDeployment.id}/${key.appConfigurationKey}')}'
  params: {
    environment: environment
    region: region
    appConfigurationName: appConfigurationName
    appConfigurationKeyName: key.appConfigurationKey
    appConfigurationValue: key.appConfigurationValue
    appConfigurationContentType: key.appConfigurationValueContentType
    appConfigurationValueLabels: contains(key, 'appConfigurationLabels') ? key.appConfigurationLabels : []
  }
}]

// 2. Deploys a private endpoint, if applicable, for an instance of Azure App Configuration
module azAppConfigurationPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(appConfigurationPrivateEndpoint)) {
  name: !empty(appConfigurationPrivateEndpoint) ? toLower('az-app-cfg-pri-endp-${guid('${azAppConfigurationDeployment.id}/${appConfigurationPrivateEndpoint.privateEndpointName}')}') : 'no-app-cfg-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: appConfigurationPrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(appConfigurationPrivateEndpoint, 'privateEndpointLocation') ? appConfigurationPrivateEndpoint.privateEndpointLocation : appConfigurationLocation
    privateEndpointDnsZoneName: appConfigurationPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-azconfig-io'
    privateEndpointDnsZoneResourceGroup: appConfigurationPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: appConfigurationPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: appConfigurationPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: appConfigurationPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azAppConfigurationDeployment.id
    privateEndpointGroupIds: [
      'configurationStores'
    ]
  }
}

// 3. Return Deployment ouput
output appConfiguration object = azAppConfigurationDeployment
