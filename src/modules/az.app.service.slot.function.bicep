@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The Function App Name to be deployed')
param appName string

@description('The name of the Function App Slot')
param appSlotName string

@description('')
param appSlotFunctionName string

@description('')
param appSlotFunctionIsDiabled bool = false


resource azAppServiceFunctionAppSlotFunction 'Microsoft.Web/sites/slots/functions@2021-01-15' = {
  name: replace(replace('${appName}/${appSlotName}/${appSlotFunctionName}','@environment', environment), '@location', location)
  properties: {
     isDisabled: appSlotFunctionIsDiabled
  }
}
