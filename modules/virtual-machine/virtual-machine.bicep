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
param virtualMachineName string

@description('')
param virtualMachineLocation string = resourceGroup().location

@allowed([
  'Standard_B2s'
])
param virtualMachineSize string

@allowed([
  '1'
  '2'
  '3'
])
@description('')
param virtualMachineZone string = '1'

@secure()
@description('')
param virtualMachineUsername string
@secure()
@description('')
param virtualMachinePassword string

@description('')
param virtualMachineImage object

@description('')
param virtualMachineNetworkConfig object

@description('')
param virtualMachineDiskConfig object

@description('')
param virtualMachineEnableMsi bool = false

@description('')
param virtualMachineOsConfig object = {}

@description('The tags to attach to the resource when deployed')
param virtualMachineTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${formatName(virtualMachineName, affix, environment, region)}.nic.${guid(formatName(virtualMachineName, affix, environment, region))}'
  location: virtualMachineLocation
  properties: {
    ipConfigurations: [
      {
        name: '${formatName(virtualMachineName, affix, environment, region)}-ip-config'
        properties: {
          subnet: {
            id: resourceId(
              formatName(virtualMachineNetworkConfig.virtualNetworkResourceGroup, affix, environment, region),
              'Microsoft.Network/virtualNetworks/subnets',
              formatName(virtualMachineNetworkConfig.virtualNetwork, affix, environment, region),
              formatName(virtualMachineNetworkConfig.virtualNetworkSubnet, affix, environment, region)
            )
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(
              formatName(virtualMachineNetworkConfig.publicIpResourceGroup, affix, environment, region),
              'Microsoft.Network/publicIPAddresses',
              formatName(virtualMachineNetworkConfig.publicIp, affix, environment, region)
            )
            properties: {
              deleteOption: 'Detach'
            }
          }
        }
      }
    ]
  }
  dependsOn: []
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: formatName(virtualMachineName, affix, environment, region)
  location: virtualMachineLocation
  identity: {
    type: virtualMachineEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  zones: [virtualMachineZone]
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: virtualMachineDiskConfig.?diskSize ?? 1024
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: contains(virtualMachineDiskConfig.diskSku, environment)
            ? virtualMachineDiskConfig.diskSku[environment]
            : virtualMachineDiskConfig.diskSku.default
        }
      }
      imageReference: virtualMachineImage
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: contains(virtualMachineOsConfig, 'osName')
        ? formatName(virtualMachineOsConfig.?osName, affix, environment, region)
        : formatName(virtualMachineName, affix, environment, region)
      adminUsername: virtualMachineUsername
      adminPassword: virtualMachinePassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: virtualMachineOsConfig.?osPatchMode ?? 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: virtualMachineOsConfig.?osRebootSettings ?? 'IfRequired'
          }
        }
      }
    }
  }
  tags: union(virtualMachineTags, {
    region: empty(region) ? 'n/a' : region
    environment: empty(environment) ? 'n/a' : environment
  })
}
