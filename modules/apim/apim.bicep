@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

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

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

// Set the resource SKU
var apimSku = contains(apimGatewaySku, environment)
  ? {
      name: apimGatewaySku[environment].name
      capacity: apimGatewaySku[environment].capacity
    }
  : {
      name: apimGatewaySku.default.name
      capacity: apimGatewaySku.default.capacity
    }

// Create Dynamic Property for APIM connectivity type
var apimProperties = empty(apimGatewayConnectivityType)
  ? {
      virtualNetworkType: 'None'
    }
  : apimGatewayConnectivityType.connectivityType == 'Virtual Network' && (apimSku.name == 'Developer' || apimSku.name == 'Premium')
      ? {
          // Only Developer & Premium SKUs can have virtual network configuration
          publicIpAddressId: resourceId(
            formatName(apimGatewayConnectivityType.publicIpAddressResourceGroup, affix, environment, region),
            'Microsoft.Network/publicIPAddresses',
            formatName(apimGatewayConnectivityType.publicIpAddressName, affix, environment, region)
          )
          virtualNetworkType: apimGatewayConnectivityType.virtualNetworkType
          virtualNetworkConfiguration: {
            subnetResourceId: resourceId(
              formatName(apimGatewayConnectivityType.virtualNetworkResourceGroup, affix, environment, region),
              'Microsoft.Network/virtualNetworks/subnets',
              formatName(apimGatewayConnectivityType.virtualNetworkName, affix, environment, region),
              formatName(apimGatewayConnectivityType.virtualNetworkSubnetName, affix, environment, region)
            )
          }
        }
      : apimGatewayConnectivityType.connectivityType == 'Private Endpoint'
          ? {
              // TODO: Need to added Privante Endpoint Functionality
            }
          : {}

var apimCustomDomains = [
  for domain in apimGatewayConfigs.customDomains ?? []: {
    hostName: formatName(domain.domainName, affix, environment, region)
    type: domain.domainType
    certificateSource: domain.domainCertificate.sourceType
    keyVaultId: domain.domainCertificate.sourceType != 'KeyVault'
      ? null
      : formatName(domain.domainCertificate.sourceReference, affix, environment, region)
    negotiateClientCertificate: contains(domain.domainCertificate, 'negotiateClientCertificate')
      ? domain.domainCertificate.negotiateClientCertificate
      : false
    defaultSslBinding: contains(domain.domainCertificate, 'isDefaultSslBinding')
      ? domain.domainCertificate.isDefaultSslBinding
      : false
  }
]

// 1. Deploy APIM Gateway
resource apimGateway 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: formatName(apimGatewayName, affix, environment, region)
  location: apimGatewayLocation
  identity: {
    type: contains(apimGatewayConfigs, 'enableMsi') && apimGatewayConfigs.enableMsi == true ? 'SystemAssigned' : 'None'
  }
  sku: apimSku
  properties: union(
    {
      publicNetworkAccess: contains(apimGatewayConfigs, 'publicNetworkAccess')
        ? apimGatewayConfigs.publicNetworkAccess
        : 'Enabled'
      publisherEmail: apimGatewayPublisherEmail
      publisherName: apimGatewayPublisher
      hostnameConfigurations: apimCustomDomains
    },
    apimProperties
  )
  tags: union(apimGatewayTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

// RBAC is here for assigning
module apimGatewayRbac '../rbac/rbac.bicep' = [
  for appRoleAssignment in apimGatewayMsiRoleAssignments: if (contains(apimGatewayConfigs, 'enableMsi') && apimGatewayConfigs.enableMsi == true && !empty(apimGatewayMsiRoleAssignments)) {
    name: 'apim-rbac-${guid('${apimGatewayName}-${appRoleAssignment.resourceRoleName}')}'
    scope: resourceGroup(formatName(appRoleAssignment.resourceGroupToScopeRoleAssignment, affix, environment, region))
    params: {
      affix: affix
      region: region
      environment: environment
      resourceRoleName: appRoleAssignment.resourceRoleName
      resourceToScopeRoleAssignment: appRoleAssignment.resourceToScopeRoleAssignment
      resourceGroupToScopeRoleAssignment: appRoleAssignment.resourceGroupToScopeRoleAssignment
      resourceRoleAssignmentScope: appRoleAssignment.resourceRoleAssignmentScope
      resourceTypeAssigningRole: appRoleAssignment.resourceTypeAssigningRole
      resourcePrincipalIdReceivingRole: apimGateway.identity.principalId
    }
  }
]

// Deploy Certificates, if any
module apimGatewayCertificate 'apim-certificate.bicep' = [
  for certificate in apimGatewayCertificates: if (!empty(apimGatewayCertificates)) {
    name: !empty(apimGatewayCertificates)
      ? 'apim-cert-${guid('${apimGatewayName}/${certificate.apimGatewayCertificateName}')}'
      : 'no-apim-certs-to-deploy'
    scope: resourceGroup()
    params: {
      affix: affix
      region: region
      environment: environment
      apimGatewayName: apimGatewayName
      apimGatewayCertificateName: certificate.apimGatewayCertificateName
      apimGatewayCertificateKeyVaultReference: certificate.apimGatewayCertificateKeyVaultReference
    }
    dependsOn: [
      apimGatewayRbac
    ]
  }
]

// Deploy Backends, if any
module apimGatewayBackend 'apim-backend.bicep' = [
  for backend in apimGatewayBackends: if (!empty(apimGatewayBackends)) {
    name: !empty(apimGatewayBackends)
      ? 'apim-backend-${guid('${apimGatewayName}/${backend.apimGatewayBackendName}')}'
      : 'no-apim-backends-to-deploy'
    params: {
      affix: affix
      region: region
      environment: environment
      apimGatewayName: apimGatewayName
      apimGatewayBackendName: backend.apimGatewayBackendName
      apimGatewayBackendType: backend.apimGatewayBackendType
      apimGatewayBackendDescription: backend.?apimGatewayBackendDescription
      apimGatewayBackendRuntimeUrl: backend.?apimGatewayBackendRuntimeUrl
      apimGatewayBackendTitle: backend.?apimGatewayBackendTitle
      apimGatewayBackendSiteResourceGroupName: backend.?apimGatewayBackendSiteResourceGroupName
      apimGatewayBackendSiteResourceName: backend.?apimGatewayBackendSiteResourceName
    }
    dependsOn: [
      apimGateway
    ]
  }
]

// Deploy Loggers, if any
module apimGatewayLogger 'apim-logger.bicep' = [
  for logger in apimGatewayLoggers: if (!empty(apimGatewayLoggers)) {
    name: !empty(apimGatewayLoggers)
      ? 'apim-logger-${guid('${apimGatewayName}/${logger.apimGatewayLoggerResourceName}')}'
      : 'no-apim-loggers-to-deploy'
    params: {
      affix: affix
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
  }
]

// Deploy APIs, if any
module apimGatewayApi 'apim-api.bicep' = [
  for api in apimGatewayApis: if (!empty(apimGatewayApis)) {
    name: !empty(apimGatewayApis)
      ? 'apim-api-${guid('${apimGatewayName}/${api.apimGatewayApiName}')}'
      : 'no-apim-apis-to-deploy'
    params: {
      affix: affix
      region: region
      environment: environment
      apimGatewayName: apimGatewayName
      apimGatewayApiName: api.apimGatewayApiName
      apimGatewayApiPath: api.apimGatewayApiPath
      apimGatewayApiDescription:  api.?api.apimGatewayApiDescription 
      apimGatewayApiOperations:  api.?apimGatewayApiOperations 
      apimGatewayApiPolicy:  api.?apimGatewayApiPolicy 
      apimGatewayApiProtocols:  api.?apimGatewayApiProtocols 
      apimGatewayApiType:  api.?apimGatewayApiType 
      apimGatewayApiSubscriptionRequired: api.?apimGatewayApiSubscriptionRequired
      apimGatewayApiAuthenticationConfigs: api.?apimGatewayApiAuthenticationConfigs
    }
    dependsOn: [
      apimGateway
    ]
  }
]

output apimGateway object = apimGateway
