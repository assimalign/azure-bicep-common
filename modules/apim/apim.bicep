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

@description('The name of the API Management resource')
param apimGatewayName string

@description('The location in which the APIM Gateway will be deployed to.')
param apimGatewayLocation string = resourceGroup().location

@description('The organization name of the published gateway')
param apimGatewayPublisher string

@description('The email address of the publisher')
param apimGatewayPublisherEmail string

@description('The pricing tier for the APIM resource')
param apimGatewaySku object

@description('')
param apimGatewayConfigs object = {}

@description('')
param apimGatewayMsiRoleAssignments array = []

@description('')
param apimGatewayConnectivityType object = {}

@description('')
param apimGatewayApis array = []

@description('Certificates to be deployed with the APIM Gateway.')
param apimGatewayCertificates array = []

@description('Backends to be deployed with the APIM Gateway.')
param apimGatewayBackends array = []

@description('')
param apimGatewayLoggers array = []

@description('The tags to attach to the resource when deployed')
param apimGatewayTags object = {}

// Set the resource SKU
var apimSku = contains(apimGatewaySku, environment) ? {
  name: apimGatewaySku[environment].name
  capacity: apimGatewaySku[environment].capacity
} : {
  name: apimGatewaySku.default.name
  capacity: apimGatewaySku.default.capacity
}

// Create Dynamic Property for APIM connectivity type
var apimProperties = empty(apimGatewayConnectivityType) ? {
  virtualNetworkType: 'None'
} : apimGatewayConnectivityType.connectivityType == 'Virtual Network' && (apimSku.name == 'Developer' || apimSku.name == 'Premium') ? {// Only Developer & Premium SKUs can have virtual network configuration
  publicIpAddressId: replace(replace(resourceId(apimGatewayConnectivityType.publicIpAddressResourceGroup, 'Microsoft.Network/publicIPAddresses', apimGatewayConnectivityType.publicIpAddressName), '@environment', environment), '@region', region)
  virtualNetworkType: apimGatewayConnectivityType.virtualNetworkType
  virtualNetworkConfiguration: {
    subnetResourceId: replace(replace(resourceId(apimGatewayConnectivityType.virtualNetworkResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', apimGatewayConnectivityType.virtualNetworkName, apimGatewayConnectivityType.virtualNetworkSubnetName), '@environment', environment), '@region', region)
  }
} : apimGatewayConnectivityType.connectivityType == 'Private Endpoint' ? {
  // TODO: Need to added Privante Endpoint Functionality
} : {}

var apimCustomDomains = [for domain in apimGatewayConfigs.customDomains ?? []: {
  hostName: replace(replace(domain.domainName, '@environment', environment), '@region', region)
  type: domain.domainType
  certificateSource: domain.domainCertificate.sourceType
  keyVaultId: domain.domainCertificate.sourceType != 'KeyVault' ? null : replace(replace(domain.domainCertificate.sourceReference, '@environment', environment), '@region', region)
  negotiateClientCertificate: contains(domain.domainCertificate, 'negotiateClientCertificate') ? domain.domainCertificate.negotiateClientCertificate : false
  defaultSslBinding: contains(domain.domainCertificate, 'isDefaultSslBinding') ? domain.domainCertificate.isDefaultSslBinding : false
}]

// 1. Deploy APIM Gateway
resource apimGateway 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: replace(replace(apimGatewayName, '@environment', environment), '@region', region)
  location: apimGatewayLocation
  identity: {
    type: contains(apimGatewayConfigs, 'enableMsi') && apimGatewayConfigs.enableMsi == true ? 'SystemAssigned' : 'None'
  }
  sku: apimSku
  properties: union({
      publicNetworkAccess: contains(apimGatewayConfigs, 'publicNetworkAccess') ? apimGatewayConfigs.publicNetworkAccess : 'Enabled'
      publisherEmail: apimGatewayPublisherEmail
      publisherName: apimGatewayPublisher
      hostnameConfigurations: apimCustomDomains
    }, apimProperties)
  tags: union(apimGatewayTags, {
      region: empty(region) ? 'n/a' : region
      environment: empty(environment) ? 'n/a' : environment
    }
  )
}

// RBAC is here for assigning
module apimGatewayRbac '../rbac/rbac.bicep' = [for appRoleAssignment in apimGatewayMsiRoleAssignments: if (contains(apimGatewayConfigs, 'enableMsi') && apimGatewayConfigs.enableMsi == true && !empty(apimGatewayMsiRoleAssignments)) {
  name: 'apim-rbac-${guid('${apimGatewayName}-${appRoleAssignment.resourceRoleName}')}'
  scope: resourceGroup(replace(replace(appRoleAssignment.resourceGroupToScopeRoleAssignment, '@environment', environment), '@region', region))
  params: {
    region: region
    environment: environment
    resourceRoleName: appRoleAssignment.resourceRoleName
    resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
    resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
    resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
    resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
    resourcePrincipalIdReceivingRole: apimGateway.identity.principalId
  }
}]

// Deploy Certificates, if any
module apimGatewayCertificate 'apim-certificate.bicep' = [for certificate in apimGatewayCertificates: if (!empty(apimGatewayCertificates)) {
  name: !empty(apimGatewayCertificates) ? 'apim-cert-${guid('${apimGatewayName}/${certificate.apimGatewayCertificateName}')}' : 'no-apim-certs-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    apimGatewayName: apimGatewayName
    apimGatewayCertificateName: certificate.apimGatewayCertificateName
    apimGatewayCertificateKeyVaultReference: certificate.apimGatewayCertificateKeyVaultReference
  }
  dependsOn: [
    apimGatewayRbac
  ]
}]

// Deploy Backends, if any
module apimGatewayBackend 'apim-backend.bicep' = [for backend in apimGatewayBackends: if (!empty(apimGatewayBackends)) {
  name: !empty(apimGatewayBackends) ? 'apim-backend-${guid('${apimGatewayName}/${backend.apimGatewayBackendName}')}' : 'no-apim-backends-to-deploy'
  params: {
    region: region
    environment: environment
    apimGatewayName: apimGatewayName
    apimGatewayBackendName: backend.apimGatewayBackendName
    apimGatewayBackendType: backend.apimGatewayBackendType
    apimGatewayBackendDescription: contains(backend, 'apimGatewayBackendDescription') ? backend.apimGatewayBackendDescription : ''
    apimGatewayBackendRuntimeUrl: contains(backend, 'apimGatewayBackendRuntimeUrl') ? backend.apimGatewayBackendRuntimeUrl : ''
    apimGatewayBackendTitle: contains(backend, 'apimGatewayBackendTitle') ? backend.apimGatewayBackendTitle : ''
    apimGatewayBackendSiteResourceGroupName: contains(backend, 'apimGatewayBackendSiteResourceGroupName') ? backend.apimGatewayBackendSiteResourceGroupName : ''
    apimGatewayBackendSiteResourceName: contains(backend, 'apimGatewayBackendSiteResourceName') ? backend.apimGatewayBackendSiteResourceName : ''
  }
  dependsOn: [
    apimGateway
  ]
}]

// Deploy Loggers, if any
module apimGatewayLogger 'apim-logger.bicep' = [for logger in apimGatewayLoggers: if (!empty(apimGatewayLoggers)) {
  name: !empty(apimGatewayLoggers) ? 'apim-logger-${guid('${apimGatewayName}/${logger.apimGatewayLoggerResourceName}')}' : 'no-apim-loggers-to-deploy'
  params: {
    region: region
    environment: environment
    apimGatewayName: apimGatewayName
    apimGatewayLoggerType: logger.apimGatewayLoggerType
    apimGatewayLoggerResourceName: logger.apimGatewayLoggerResourceName
    apimGatewayLoggerResourceGroup: logger.apimGatewayLoggerResourceGroup
  }
  dependsOn: [
    apimGateway
  ]
}]

// Deploy APIs, if any
module apimGatewayApi 'apim-api.bicep' = [for api in apimGatewayApis: if (!empty(apimGatewayApis)) {
  name: !empty(apimGatewayApis) ? 'apim-api-${guid('${apimGatewayName}/${api.apimGatewayApiName}')}' : 'no-apim-apis-to-deploy'
  params: {
    region: region
    environment: environment
    apimGatewayName: apimGatewayName
    apimGatewayApiName: api.apimGatewayApiName
    apimGatewayApiPath: api.apimGatewayApiPath
    apimGatewayApiDescription: contains(api, 'apimGatewayApiDescription') ? api.api.apimGatewayApiDescription : ''
    apimGatewayApiOperations: contains(api, 'apimGatewayApiOperations') ? api.apimGatewayApiOperations : []
    apimGatewayApiPolicy: contains(api, 'apimGatewayApiPolicy') ? api.apimGatewayApiPolicy : ''
    apimGatewayApiProtocols: contains(api, 'apimGatewayApiProtocols') ? api.apimGatewayApiProtocols : [ 'https' ]
    apimGatewayApiType: contains(api, 'apimGatewayApiType') ? api.apimGatewayApiType : 'http'
    apimGatewayApiSubscriptionRequired: contains(api, 'apimGatewayApiSubscriptionRequired') ? api.apimGatewayApiSubscriptionRequired : true
    apimGatewayApiAuthenticationConfigs: contains(api, 'apimGatewayApiAuthenticationConfigs') ? api.apimGatewayApiAuthenticationConfigs : {}
  }
  dependsOn: [
    apimGateway
  ]
}]

output apimGateway object = apimGateway
