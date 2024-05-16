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

@description('')
param frontDoorName string

@description('')
param frontDoorLocation string = resourceGroup().location

@description('')
param frontDoorTags object = {}

resource azFrontDoorDeployment 'Microsoft.Network/frontDoors@2021-06-01' = {
   name: replace(replace(frontDoorName, '@environment', environment), '@region', region)
   location: frontDoorLocation
   properties: {
      backendPools: [
          {
             properties: {
                
             }
          }
      ]
      routingRules: [
          {
             
          }
      ]
   }
   tags: union(frontDoorTags, {
         region: empty(region) ? 'n/a' : region
         environment: empty(environment) ? 'n/a' : environment
      })
}

output frontDoor object = azFrontDoorDeployment
