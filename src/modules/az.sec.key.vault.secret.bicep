@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

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
module azServiceBusKeyVaultSecretDeployment 'az.sec.key.vault.secret.service.bus.bicep' = if (resourceType == 'Microsoft.ServiceBus/namespaces/authorizationRules') {
  name: 'az-key-vault-secret-sb-${guid('${keyVaultSecretName}/Microsoft.ServiceBus/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
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
module azStorageAccountKeyVaultSecretDeployment 'az.sec.key.vault.secret.storage.bicep' = if (resourceType == 'Microsoft.Storage/storageAccounts') {
  name: 'az-key-vault-secret-st-${guid('${keyVaultSecretName}/Microsoft.Storage/storageAccounts')}'
  scope: resourceGroup()
  params: {
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
module azDocumentDbKeyVaultSecretDeployment 'az.sec.key.vault.secret.documentdb.bicep' = if (resourceType == 'Microsoft.DocumentDB/databaseAccounts') {
  name: 'az-key-vault-secret-db-${guid('${keyVaultSecretName}/Microsoft.DocumentDB/databaseAccounts')}'
  scope: resourceGroup()
  params: {
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
module azEventGridKeyVaultSecretDeployment 'az.sec.key.vault.secret.event.grid.bicep' = if (resourceType == 'Microsoft.EventGrid/domains') {
  name: 'az-key-vault-secret-eg-${guid('${keyVaultSecretName}/Microsoft.EventGrid/domains')}'
  scope: resourceGroup()
  params: {
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
module azEventHubKeyVaultSecretDeployment 'az.sec.key.vault.secret.event.hub.bicep' = if (resourceType == 'Microsoft.EventHub/namespaces/authorizationRules') {
  name: 'az-key-vault-secret-eh-${guid('${keyVaultSecretName}/Microsoft.EventHub/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
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
module azNotificationHubKeyVaultSecretDeployment 'az.sec.key.vault.secret.notification.hub.bicep' = if (resourceType == 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules') {
  name: 'az-key-vault-secret-nh-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules')}'
  scope: resourceGroup()
  params: {
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
module azNotificationNamespaceKeyVaultSecretDeployment 'az.sec.key.vault.secret.notification.namespace.bicep' = if (resourceType == 'Microsoft.NotificationHubs/namespaces/authorizationRules') {
  name: 'az-key-vault-secret-nn-${guid('${keyVaultSecretName}/Microsoft.NotificationHubs/namespaces/authorizationRules')}'
  scope: resourceGroup()
  params: {
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: keyVaultSecretName
    resourceName: resourceName
    resourceGroupName: resourceGroupName
  }
}
