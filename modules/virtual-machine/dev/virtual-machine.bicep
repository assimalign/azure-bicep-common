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

@description('')
param virtualMachineName string

@description('')
param virtualMachineLocation string = resourceGroup().location

@description('')
param virtualMachineEnableMsi bool = false

@description('The tags to attach to the resource when deployed')
param virtualMachineTags object = {}

func formatName(name string, environment string, region string) string =>
  replace(replace(name, '@environment', environment), '@region', region)

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: formatName(virtualMachineName, environment, region)
  location: virtualMachineLocation
  identity: {
    type: virtualMachineEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  plan: {
     name: ''
  }

  properties: {
    osProfile: {
      windowsConfiguration: {}
    }
  }
  tags: union(virtualMachineTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
