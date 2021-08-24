@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The Function App Name to be deployed')
param appName string
@allowed([
  'web'
  'functionapp'
  'functionapp,linux' 
])
@description('appType')
param appSlotType string

param appSlotEnableMsi bool = false

@description('The name of the Function App Slot')
param appSlotName string



// 4. Deploy Function App
resource azAppServiceFunctionDeployment 'Microsoft.Web/sites/slots@2021-01-01' = if (appSlotType == 'functionapp' || appSlotType == 'functionapp,linux') {
  name: appSlotType == 'functionapp' || appSlotType == 'functionapp,linux' ? replace('${appName}/${appSlotName}', '@environment', environment) : 'no-function-app-slot-to-deploy'
  location: resourceGroup().location
  identity: {
    type: appSlotEnableMsi == true ? 'SystemAssigned' : 'None'
   } 
  properties: {
     
  }
}
