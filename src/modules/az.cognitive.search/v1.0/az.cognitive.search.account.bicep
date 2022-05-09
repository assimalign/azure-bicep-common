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
@description('Applicable only for the standard3 SKU. You can set this property to enable up to 3 high density partitions that allow up to 1000 indexes, which is much higher than the maximum indexes allowed for any other SKU. For the standard3 SKU, the value is either default or highDensity. For all other SKUs, this value must be default.')
param cognitiveSearchHostingMode string = 'default'

@description('Specifies whether public network access should be enabled or diabled. False is the default.')
param cognitiveSearchDisablePublicAccess bool = true

@description('The tags to attach to the resource when deployed')
param cognitiveSearchTags object = {}

var sku = any((environment == 'dev') ? {
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

resource azCognitiveSearchDeployment 'Microsoft.Search/searchServices@2020-08-01' = {
  name: replace(replace(cognitiveSearchName, '@environment', environment), '@region', region)
  location: cognitiveSearchLocation
  sku: sku
  properties: {
    hostingMode: cognitiveSearchHostingMode
    publicNetworkAccess: cognitiveSearchDisablePublicAccess && sku.name != 'free' ? 'disabled' : 'enabled'
  }
  tags: cognitiveSearchTags
}

output cognitiveSearch object = azCognitiveSearchDeployment
