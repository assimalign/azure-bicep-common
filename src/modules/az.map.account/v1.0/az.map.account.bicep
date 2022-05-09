





resource azMapAccountDeployment 'Microsoft.Maps/accounts@2021-02-01' = {
   name: ''
    sku: {
      name:  'G2'
    }
    properties: {
       disableLocalAuth: 
    }
}
