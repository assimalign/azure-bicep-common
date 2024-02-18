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

@description('the name of the key vault to be deployed. NOTE: Prefix and environment name are not included in this resource deployment')
param keyVaultName string

@description('The supported Azure location where the key vault should be created.')
param keyVaultLocation string = resourceGroup().location

@description('The pricing tier for the key vault resource')
param keyVaultSku object = {
  dev: 'Standard'
  qa: 'Standard'
  uat: 'Standard'
  prd: 'Standard'
  default: 'Standard'
}

@description('')
param keyVaultConfigs object = {}

@description('The private endpoint to create or update for the key vault')
param keyVaultPrivateEndpoint object = {}

@allowed([
  'Allow'
  'Deny'
])
@description('The default action when no rule from ipRules and from virtualNetworkRules match. This is only used after the bypass property has been evaluated.')
param keyVaultDefaultNetworkAccess string = 'Allow'

@description('The virtual networks to allow access to the deployed key vault')
param keyVaultVirtualNetworkAccessRules array = []

@description('')
param keyVaultIpAddressAccessRules array = []

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

@description('Custom attributes to attach to key vault deployment')
param keyVaultTags object = {}

// 3. Deploy Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: replace(replace(keyVaultName, '@environment', environment), '@region', region)
  location: keyVaultLocation
  properties: {
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    createMode: keyVaultCreationMode
    accessPolicies: [for policy in keyVaultPolicies: {
      tenantId: subscription().tenantId
      objectId: policy.objectId
      permissions: policy.permissions
    }]
    publicNetworkAccess: contains(keyVaultConfigs, 'keyVaultAllowPublicNetworkAccess') ? keyVaultConfigs.keyVaultAllowPublicNetworkAccess : 'Enabled'
    enableRbacAuthorization: contains(keyVaultConfigs, 'keyVaultRbacEnabled') ? keyVaultConfigs.keyVaultRbacEnabled : false
    enableSoftDelete: contains(keyVaultConfigs, 'keyVaultSoftDeleteEnabled') ? keyVaultConfigs.keyVaultSoftDeleteEnabled : true
    softDeleteRetentionInDays: contains(keyVaultConfigs, 'keyVaultSoftDeleteRetention') ? keyVaultConfigs.keyVaultSoftDeleteRetention : 7
    enablePurgeProtection: contains(keyVaultConfigs, 'keyVaultPurgeProtectionEnabled') ? keyVaultConfigs.keyVaultPurgeProtectionEnabled : json('null')
    sku: any(contains(keyVaultSku, environment) ? {
      name: keyVaultSku[environment]
      family: 'A'
    } : {
      name: keyVaultSku.default
      family: 'A'
    })
    networkAcls: {
      defaultAction: keyVaultDefaultNetworkAccess
      ipRules: [for ip in keyVaultIpAddressAccessRules: {
        value: ip.ipAddress
      }]
      virtualNetworkRules: [for networkRule in keyVaultVirtualNetworkAccessRules: {
        id: any(replace(replace(resourceId('${networkRule.virtualNetworkResourceGroup}', 'Microsoft.Network/virtualNetworks/subnets', '${networkRule.virtualNetwork}', networkRule.virtualNetworkSubnet), '@environment', environment), '@region', region))
      }]
    }
  }
  tags: union(keyVaultTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    })
}

module azKeyVaultSecretDeployment 'key-vault-secret.bicep' = [for secret in keyVaultSecrets: if (!empty(keyVaultSecrets)) {
  name: !empty(keyVaultSecrets) ? toLower('kv-secret-${guid('${keyVault.id}/${secret.keyVaultSecretName}')}') : 'no-key-vault-secrets-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: secret.keyVaultSecretName
    keyVaultSecretResourceName: secret.keyVaultSecretResourceName
    keyVaultSecretResourceType: secret.keyVaultSecretResourceType
    keyVaultSecretResourceGroupOfResource: secret.keyVaultSecretResourceGroupOfResource
  }
}]

module azKeyVaultKeyDeployment 'key-vault-key.bicep' = [for key in keyVaultKeys: if (!empty(keyVaultKeys)) {
  name: !empty(keyVaultKeys) ? toLower('kv-key-${guid('${keyVault.id}/${key.name}')}') : 'no-key-vault-keys-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultKeyName: key.name
    keyVaultKeySize: key.size
    keyVaultKeyCurveName: key.curveName
    keyVaultKeyTags: keyVaultTags
  }
}]

module keyVaultPrivateEp '../private-endpoint/private-endpoint.bicep' = if (!empty(keyVaultPrivateEndpoint)) {
  name: !empty(keyVaultPrivateEndpoint) ? toLower('az-kv-priv-endpoint-${guid('${keyVault.id}/${keyVaultPrivateEndpoint.privateEndpointName}')}') : 'no-key-vault-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: keyVaultPrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(keyVaultPrivateEndpoint, 'privateEndpointLocation') ? keyVaultPrivateEndpoint.privateEndpointLocation : keyVaultLocation
    privateEndpointDnsZoneName: keyVaultPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-vaultcore-azure-net'
    privateEndpointDnsZoneResourceGroup: keyVaultPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: keyVault.id
    privateEndpointTags: contains(keyVaultPrivateEndpoint, 'privateEndpointTags') ? keyVaultPrivateEndpoint.privateEndpointTags : {}
    privateEndpointGroupIds: [
      'vault'
    ]
  }
}

output keyVault object = keyVault
