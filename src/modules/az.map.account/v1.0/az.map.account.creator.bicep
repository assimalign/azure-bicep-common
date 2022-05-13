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

@description('The name of the Map Account to be deployed.')
param mapAccountName string









resource azMapAccountCreatorDeployment 'Microsoft.Maps/accounts/creators@2021-02-01' = {
  name: replace(replace('${mapAccountName}/${}', '@environment', environment), '@region', region)
  
} 
