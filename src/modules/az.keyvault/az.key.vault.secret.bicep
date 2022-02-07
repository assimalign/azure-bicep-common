@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix for the resource name')
param location string = ''

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string

@description('The resource type tells what azure resource keys need to be obtained')
param resourceType  string 


// ************************************************************************** //
//                 Service Bus Primary Connection String Update
// ************************************************************************** //
module azServiceBusKeyVaultSecretDeployment 'az.key.vault.secret.service.bus.bicep' = if (resourceType == 'Microsoft.ServiceBus/namespaces/authorizationRules') {
  name: 'az-kv-secret-sb-${guid('${keyVaultSecretName}/Microsoft.ServiceBus/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}


// ************************************************************************** //
//                 Storage Account Primary Connection String Update
// ************************************************************************** //
module azStorageAccountKeyVaultSecretDeployment 'az.key.vault.secret.storage.bicep' = if (resourceType == 'Microsoft.Storage/storageAccounts') {
  name: 'az-kv-secret-stg-${guid('${keyVaultSecretName}/Microsoft.Storage/storageAccounts')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}


// ************************************************************************** //
//              Document Db Primary Connection String & Key Update
// ************************************************************************** //
module azDocumentDbKeyVaultSecretDeployment 'az.key.vault.secret.documentdb.bicep' = if (resourceType == 'Microsoft.DocumentDB/databaseAccounts') {
  name: 'az-kv-secret-cosmos-${guid('${keyVaultSecretName}/Microsoft.DocumentDB/databaseAccounts')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}


// ************************************************************************** //
//                       Event Grid Domain Key Update
// ************************************************************************** //
module azEventGridKeyVaultSecretDeployment 'az.key.vault.secret.event.grid.bicep' = if (resourceType == 'Microsoft.EventGrid/domains') {
  name: 'az-kv-secret-egd-${guid('${keyVaultSecretName}/Microsoft.EventGrid/domains')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}


// ************************************************************************** //
//                       Event Hub Namespace Key Update
// ************************************************************************** //
module azEventHubKeyVaultSecretDeployment 'az.key.vault.secret.event.hub.bicep' = if (resourceType == 'Microsoft.EventHub/namespaces/authorizationRules') {
  name: 'az-kv-secret-ehn-${guid('${keyVaultSecretName}/Microsoft.EventHub/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}


// ************************************************************************** //
//                       Notification Hub Key Update
// ************************************************************************** //
module azNotificationHubKeyVaultSecretDeployment 'az.key.vault.secret.notification.hub.bicep' = if (resourceType == 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules') {
  name: 'az-kv-secret-nhn-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}



// ************************************************************************** //
//                       Notificaiton Hub Namespace Key Update
// ************************************************************************** //
module azNotificationNamespaceKeyVaultSecretDeployment 'az.key.vault.secret.notification.namespace.bicep' = if (resourceType == 'Microsoft.NotificationHubs/namespaces/authorizationRules') {
  name: 'az-kv-secret-nh-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}
