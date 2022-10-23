




resource asDataFactoryIntegrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {

name: ''
 properties: {
  type:  'SelfHosted'
  typeProperties: {
    linkedInfo: {
      authorizationType: 'RBAC'
       credential: {
        referenceName:  
        type:  'CredentialReference'
       }
       resourceId: 
      key: {
        type:  
        value: 
      }
    }
  }
 }
}
