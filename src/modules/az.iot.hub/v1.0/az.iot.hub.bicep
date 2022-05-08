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

@description('')
param iotHubName string




resource azIotHubDeployment 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: replace(replace(iotHubName, '@environment', environment), '@region', region)
   sku: {
      name: 'S1'
   }
   properties: {
       
   }
}



output resource object = azIotHubDeployment
