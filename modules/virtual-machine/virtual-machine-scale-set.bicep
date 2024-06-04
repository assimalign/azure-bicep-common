@allowed([
  ''
  'demo'
  'stg'
  'sbx'
  'test'
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('Add an affix (suffix/prefix) to a resource name.')
param affix string = ''

@description('')
param virtualMachineScaleSetName string

@description('')
param virtualMachineScaleSetPrefixName string

@description('')
param virtualMachineScaleSetLocation string = resourceGroup().location

@description('')
param virtualMachineScaleSetEnableMsi bool = true

@description('')
param virtualMachineScaleSetSku object = {}

@secure()
@description('')
param virtualMachineScaleSetUsername string

@secure()
@description('')
param virtualMachineScaleSetPassword string

@description('')
param virtualMachineScaleSetImage object

@description('')
param virtualMachineScaleSetDiskConfig object

@description('')
param virtualMachineScaleSetNetworkConfig object

@description('')
param virtualMachineScaleSetConfig object = {}

@description('The tags to attach to the resource when deployed')
param virtualMachineScaleSetTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource virtualMachineScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  name: formatName(virtualMachineScaleSetName, affix, environment, region)
  location: virtualMachineScaleSetLocation
  sku: contains(virtualMachineScaleSetSku, environment)
    ? {
        name: virtualMachineScaleSetSku[environment].name
        capacity: virtualMachineScaleSetSku[environment].capacity
      }
    : {
        name: virtualMachineScaleSetSku.default.name
        capacity: virtualMachineScaleSetSku.default.capacity
      }
  identity: {
    type: virtualMachineScaleSetEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    orchestrationMode: virtualMachineScaleSetConfig.?orchestrationMode ?? 'Flexible'
    platformFaultDomainCount: virtualMachineScaleSetConfig.?platformFaultDomainCount ?? 1
    upgradePolicy: {
      mode:  virtualMachineScaleSetConfig.?upgradePolicy ?? 'Manual'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    scaleInPolicy: virtualMachineScaleSetConfig.?scaleInPolicy ?? {
        rules: [
          'Default'
        ]
        forceDeletion: false
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: formatName(virtualMachineScaleSetPrefixName, affix, environment, region)
        adminUsername: virtualMachineScaleSetUsername
        adminPassword: virtualMachineScaleSetPassword
      }
      storageProfile: {
        osDisk: {
          createOption: 'fromImage'
          diskSizeGB: virtualMachineScaleSetDiskConfig.?diskSize ?? 1024
          managedDisk: {
            storageAccountType: contains(virtualMachineScaleSetDiskConfig.diskSku, environment)
              ? virtualMachineScaleSetDiskConfig.diskSku[environment]
              : virtualMachineScaleSetDiskConfig.diskSku.default
          }
        }
        imageReference: virtualMachineScaleSetImage
      }
      networkProfile: {
         networkInterfaceConfigurations: [for networkInterface in virtualMachineScaleSetNetworkConfig.networkInterfaces: {
            name: formatName(networkInterface.networkInterfaceName, affix, environment, region)
            properties: {
              primary: true
              networkSecurityGroup: contains(networkInterface, 'networkInterfaceSecurityGroup') ? {
                id: resourceId(
                  formatName(networkInterface.networkInterfaceSecurityGroup.networkSecurityGroupResourceGroup, affix, environment, region),
                  'Microsoft.Network/networkSecurityGroups',
                  formatName(networkInterface.networkInterfaceSecurityGroup.networkSecurityGroupName, affix, environment, region)
                )
              } : null
              ipConfigurations: [ {
                  name:  formatName(networkInterface.networkInterfaceIpConfig.ipConfigName, affix, environment, region)
                  properties: {
                    primary: true
                    publicIPAddressConfiguration: {
                      name: formatName(networkInterface.networkInterfaceIpConfig.ipConfigPublicIpName, affix, environment, region)
                    }
                     subnet: {
                       id: resourceId(
                        formatName(networkInterface.networkInterfaceIpConfig.ipConfigVirtualNetworkResourceGroup, affix, environment, region),
                        'Microsoft.Network/virtualNetworks/subnets',
                        formatName(networkInterface.networkInterfaceIpConfig.ipConfigVirtualNetwork, affix, environment, region),
                        formatName(networkInterface.networkInterfaceIpConfig.ipConfigVirtualNetworkSubnet, affix, environment, region)
                       )
                     }
                  }
                 }
              ]
            }
           }
         ]
      }
    }
  }
  tags: union(virtualMachineScaleSetTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
