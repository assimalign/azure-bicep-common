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

@description('The name of the Azure Cognitive Search Service to be deployed.')
param cognitiveSearchName string

@description('The location the Azure Cognitive Search Service will be deployed to.')
param cognitiveSearchLocation string = resourceGroup().location

@description('The pricing tier of the Azure Cognitive Search Service.')
param cognitiveSearchSku object = {
  dev: 'free'
  qa: 'free'
  uat: 'free'
  prd: 'free'
}

@allowed([
  'default'
  'highDensity'
])
@description('')
param cognitiveSearchHostingMode string = 'default'

@description('Specifies whether public network access should be enabled or diabled. False is the default.')
param cognitiveSearchDisablePublicAccess bool = true


resource azCognitiveSearchDeployment 'Microsoft.Search/searchServices@2020-08-01' = {
  name: replace(replace(cognitiveSearchName, '@environment', environment), '@region', region)
  location: cognitiveSearchLocation
  sku: any((environment == 'dev') ? {
    name: cognitiveSearchSku.dev
  } : any((environment == 'qa') ? {
    name: cognitiveSearchSku.qa
  } : any((environment == 'uat') ? {
    name: cognitiveSearchSku.uat
  } : any((environment == 'prd') ? {
    name: cognitiveSearchSku.prd
  } : {
    name: 'Free'
  }))))
  properties: {
    hostingMode: cognitiveSearchHostingMode
    publicNetworkAccess: cognitiveSearchDisablePublicAccess ? 'disabled': 'enabled'
  }
}


output cognitiveSearch object = azCognitiveSearchDeployment
