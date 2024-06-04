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

@description('The name of the APIM Gateway the certificate will be deployed to.')
param apimGatewayName string

@description('A friendly name for the certificate.')
param apimGatewayCertificateName string

@description('Currently the module only supports certificate deployement via Key Vault. Key Vault id is required.')
param apimGatewayCertificateKeyVaultReference string

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource apimGatewayCertificate 'Microsoft.ApiManagement/service/certificates@2022-08-01' = {
  name: formatName('${apimGatewayName}/${apimGatewayCertificateName}', affix, environment, region)
  properties: {
    keyVault: {
      secretIdentifier: formatName(apimGatewayCertificateKeyVaultReference, affix, environment, region)
    }
  }
}

output apimGatewayCertificate object = apimGatewayCertificate
