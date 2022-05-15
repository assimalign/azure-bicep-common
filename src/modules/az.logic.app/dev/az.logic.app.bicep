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

resource azLogicAppDeployment 'Microsoft.Logic/workflows@2019-05-01' = {
   name: ''
   properties: {}
}
