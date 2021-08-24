@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The name of the virtual machine to be deployed')
param virtualMachineName string





resource virtualMachine 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: replace('${virtualMachineName}', '@environment', environment)
  location: resourceGroup().location
}

resource windowsVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: virtualMachine
  name: 'name'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'fileUris'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -file customScript.ps1'
    }
  }
}
