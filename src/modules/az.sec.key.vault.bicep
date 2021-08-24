@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('the name of the key vault to be deployed. NOTE: Prefix and environment name are not included in this resource deployment')
param keyVaultName string

@description('The pricing tier for the key vault resource')
param keyVaultSku object = {}

@description('The private endpoint to create or update for the key vault')
param keyVaultPrivateEndpoint object = {}

@description('')
param keyVaultEnableSoftDelete bool = true

@description('The virtual networks to allow access to the deployed key vault')
param keyVaultVirtualNetworks array = []

@allowed([
  'Allow'
  'Deny'
])
@description('')
param keyVaultDefaultNetworkAccess string = 'Allow'

@description('The access policies for obtaining keys, secrets, and certificates with the vault')
param keyVaultPolicies array = []

@description('')
param keyVaultKeys array = []

@description('Key Vault Secret References for azure resources. Specify existing resources to add as secrets for applications to use such as; storage accounts , cosmos db connection strings, etc')
param keyVaultSecrets array = []

@allowed([
  'default'
  'recover'
])
@description('The creation mode for disaster recovery')
param keyVaultCreationMode string = 'default'

@description('')
param keyVaultTags object = {}

@description('Enable RBAC (Role Based Access Control) for authroization to the key vault')
param keyVaultEnableRbac bool = false



// 1. Format the Virtual Network Access Rules for the Key Vault deployment
var virtualNetworks = [for network in keyVaultVirtualNetworks: {
  id: replace(resourceId('${network.virtualNetworkResourceGroup}', 'Microsoft.Network/virtualNetworks/subnets', '${network.virtualNetwork}', network.virtualNetworkSubnet), '@environment', environment)
}]


var policies = [for policy in keyVaultPolicies: {
  tenantId: subscription().tenantId
  objectId: policy.objectId
  permissions: policy.permissions
}]


resource azKeyVaultDeployment 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: replace(keyVaultName, '@environment', environment)
  location: resourceGroup().location
  properties: { 
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: keyVaultEnableRbac
    tenantId: subscription().tenantId
    createMode: keyVaultCreationMode
    accessPolicies: policies
    enableSoftDelete: keyVaultEnableSoftDelete
    sku: any(environment == 'dev' ? {
      name: keyVaultSku.dev
      family: 'A'
    } : any(environment == 'qa' ? {
      name: keyVaultSku.qa
      family: 'A'
    } : any(environment == 'uat' ? {
      name: keyVaultSku.uat
      family: 'A'
    } : any(environment == 'prd' ? {
      name: keyVaultSku.dev
      family: 'A'
    } : {
      name: 'Standard'
      family: 'A'
    }))))
    networkAcls: {
       defaultAction: keyVaultDefaultNetworkAccess
       virtualNetworkRules: virtualNetworks
    }
  }
  tags: keyVaultTags ?? {}
}


module azKeyVaultSecretDeployment 'az.sec.key.vault.secret.bicep' = [for secret in keyVaultSecrets: if(!empty(secret)) {
  name: !empty(keyVaultSecrets) ? toLower('az-key-vault-secret-${guid('${azKeyVaultDeployment.id}/${secret.name}')}') : 'no-key-vault-secrets-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: secret.name
    resourceName: secret.resourceName
    resourceGroupName: secret.resourceGroup
    resourceType: secret.resourceType
  }
  dependsOn: [
    azKeyVaultDeployment
  ]
}]

module azKeyVaultKeyDeployment 'az.sec.key.vault.key.bicep' = [for key in keyVaultKeys: if (!empty(key)) {
  name:  !empty(keyVaultKeys) ? toLower('az-key-vault-key-${guid('${azKeyVaultDeployment.id}/${key.name}')}') : 'no-key-vault-keys-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    keyVaultName: keyVaultName
    keyVaultKeyName: key.name
  }
  dependsOn: [
    azKeyVaultDeployment
  ]
}]


module azKeyVaultPrivateEndpointDeployment 'az.net.private.endpoint.bicep' = if(!empty(keyVaultPrivateEndpoint)) {
  name: !empty(keyVaultPrivateEndpoint) ? toLower('az-key-vault-priv-endpoint-${guid('${azKeyVaultDeployment.id}/${keyVaultPrivateEndpoint.name}')}') : 'no-key-vault-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    environment: environment
    privateEndpointName: keyVaultPrivateEndpoint.name
    privateEndpointPrivateDnsZone: keyVaultPrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-vaultcore-azure-net'
    privateEndpointPrivateDnsZoneResourceGroup: keyVaultPrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: keyVaultPrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: keyVaultPrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: keyVaultPrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azKeyVaultDeployment.id
    privateEndpointGroupIds: [
      'vault'
    ]
  }
  dependsOn: [
    azKeyVaultDeployment
  ]
}
