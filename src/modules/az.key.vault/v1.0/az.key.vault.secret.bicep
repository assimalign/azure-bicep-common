@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param keyVaultSecretResourceName string

@description('The resource type tells what azure resource keys need to be obtained')
param keyVaultSecretResourceType string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param keyVaultSecretResourceGroupOfResource string

// ************************************************************************** //
//                 Service Bus Primary Connection String Update
// ************************************************************************** //
module azServiceBusKeyVaultSecretDeployment 'az.key.vault.secret.service.bus.bicep' = if (keyVaultSecretResourceType == 'Microsoft.ServiceBus/namespaces/authorizationRules') {
  name: 'az-kv-secret-sb-${guid('${keyVaultSecretName}/Microsoft.ServiceBus/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//                 Storage Account Primary Connection String Update
// ************************************************************************** //
module azStorageAccountKeyVaultSecretDeployment 'az.key.vault.secret.storage.bicep' = if (keyVaultSecretResourceType == 'Microsoft.Storage/storageAccounts') {
  name: 'az-kv-secret-stg-${guid('${keyVaultSecretName}/Microsoft.Storage/storageAccounts')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//              Document Db Primary Connection String & Key Update
// ************************************************************************** //
module azDocumentDbKeyVaultSecretDeployment 'az.key.vault.secret.cosmosdb.bicep' = if (keyVaultSecretResourceType == 'Microsoft.DocumentDB/databaseAccounts') {
  name: 'az-kv-secret-cosmos-${guid('${keyVaultSecretName}/Microsoft.DocumentDB/databaseAccounts')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//                       Event Grid Domain Key Update
// ************************************************************************** //
module azEventGridKeyVaultSecretDeployment 'az.key.vault.secret.event.grid.bicep' = if (keyVaultSecretResourceType == 'Microsoft.EventGrid/domains') {
  name: 'az-kv-secret-egd-${guid('${keyVaultSecretName}/Microsoft.EventGrid/domains')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//                       Event Hub Namespace Key Update
// ************************************************************************** //
module azEventHubKeyVaultSecretDeployment 'az.key.vault.secret.event.hub.bicep' = if (keyVaultSecretResourceType == 'Microsoft.EventHub/namespaces/authorizationRules') {
  name: 'az-kv-secret-ehn-${guid('${keyVaultSecretName}/Microsoft.EventHub/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//                       Notification Hub Key Update
// ************************************************************************** //
module azNotificationHubKeyVaultSecretDeployment 'az.key.vault.secret.notification.hub.bicep' = if (keyVaultSecretResourceType == 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules') {
  name: 'az-kv-secret-nhn-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}

// ************************************************************************** //
//                       Notificaiton Hub Namespace Key Update
// ************************************************************************** //
module azNotificationNamespaceKeyVaultSecretDeployment 'az.key.vault.secret.notification.namespace.bicep' = if (keyVaultSecretResourceType == 'Microsoft.NotificationHubs/namespaces/authorizationRules') {
  name: 'az-kv-secret-nh-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: keyVaultSecretResourceName
    resourceGroupName: keyVaultSecretResourceGroupOfResource
  }
}
