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

@description('The name of the APIM Gateway the certificate will be deployed to.')
param apimGatewayName string

@description('A friendly name for the certificate.')
param apimGatewayCertificateName string

@description('Currently the module only supports certificate deployement via Key Vault. Key Vault id is required.')
param apimGatewayCertificateKeyVaultReference string

resource azApimGatewayCertificateDeployment 'Microsoft.ApiManagement/service/certificates@2021-12-01-preview' = {
  name: replace(replace('${apimGatewayName}/${apimGatewayCertificateName}', '@environment', environment), '@region', region)
  properties: {
    keyVault: {
      secretIdentifier: replace(replace(apimGatewayCertificateKeyVaultReference, '@environment', environment), '@region', region)
    }
  }
}

output apimGatewayCertificate object = azApimGatewayCertificateDeployment
