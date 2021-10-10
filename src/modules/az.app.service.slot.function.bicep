@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed as part of the resource naming convention')
param environment string = 'dev'

@description('A prefix or suffix identifying the deployment location as part of the naming convention of the resource')
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
