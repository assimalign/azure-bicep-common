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

@description('')
param diskName string

@description('')
param diskLocation string = resourceGroup().location

@description('')
param diskSku object = {
  default: 'StandardSSD_LRS'
}

@description('')
param diskConfig object = {}

@description('The tags to attach to the resource when deployed')
param diskTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource disk 'Microsoft.Compute/disks@2023-10-02' = {
  name: formatName(diskName, affix, environment, region)
  location: diskLocation
  sku: {
    name: contains(diskSku, environment) ? diskSku[environment] : diskSku.default
  }
  properties: {
    diskSizeGB: diskConfig.?size
    creationData: {
      createOption: 'Empty'
    }
  }
  tags: union(diskTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}

output disk object = disk
