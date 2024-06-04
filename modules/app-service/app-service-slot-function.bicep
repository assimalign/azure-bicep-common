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

@description('The Function App Name to be deployed')
param appName string

@description('The name of the Function App Slot')
param appSlotName string

@description('')
param appSlotFunctionName string

@description('')
param appSlotFunctionIsDiabled bool = false

resource appServiceSlotFunction 'Microsoft.Web/sites/slots/functions@2023-01-01' = {
  name: replace(replace(replace('${appName}/${appSlotName}/${appSlotFunctionName}', '@affix', affix), '@environment', environment), '@region', region)
  properties: {
    isDisabled: appSlotFunctionIsDiabled
  }
}

output appServiceSlotFunction object = appServiceSlotFunction 
