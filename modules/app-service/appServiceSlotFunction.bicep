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

@description('The Function App Name to be deployed')
param appName string

@description('The name of the Function App Slot')
param appSlotName string

@description('')
param appSlotFunctionName string

@description('')
param appSlotFunctionIsDiabled bool = false

resource azAppServiceFunctionAppSlotFunction 'Microsoft.Web/sites/slots/functions@2022-03-01' = {
  name: replace(replace('${appName}/${appSlotName}/${appSlotFunctionName}', '@environment', environment), '@region', region)
  properties: {
    isDisabled: appSlotFunctionIsDiabled
  }
}
