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
param networkSecurityGroupName string

@description('')
param networkSecurityGroupLocation string = resourceGroup().location

@description('')
param networkSecurityGroupOutboundRules array = []

@description('')
param networkSecurityGroupInboundRules array = []

@description('')
param networkSecurityGroupTags object = {}

func formatName(name string, affix string, environment string, region string) string =>
  replace(replace(replace(name, '@affix', affix), '@environment', environment), '@region', region)

var inboundRules = [for rule in networkSecurityGroupInboundRules: {
  name: rule.name
  properties: {
    direction: 'Inbound'
    protocol: rule.protocol
    access: rule.access
    priority: rule.priority
    description: contains(rule, 'description') ? rule.description : null
    sourceAddressPrefix: contains(rule, 'sourceType') ? rule.sourceType : '*'
    destinationAddressPrefix: contains(rule, 'destinationType') ? rule.destinationType : '*'
    destinationPortRange: contains(rule, 'destinationPorts') ? length(rule.destinationPorts) <= 1 ? first(rule.destinationPorts) : null : '*'
    destinationPortRanges: contains(rule, 'destinationPorts') && length(rule.destinationPorts) > 1 ? rule.destinationPorts : []
    sourcePortRange: contains(rule, 'sourcePorts') ? length(rule.sourcePorts) <= 1 ? first(rule.sourcePorts) : null : '*'
    sourcePortRanges: contains(rule, 'sourcePorts') && length(rule.sourcePorts) > 1 ? rule.sourcePorts : []
  }
}]
var outboundRules = [for rule in networkSecurityGroupOutboundRules: {
  name: rule.name
  properties: {
    direction: 'Outbound'
    protocol: rule.protocol
    access: rule.access
    priority: rule.priority
    description: contains(rule, 'description') ? rule.description : null
    sourceAddressPrefix: contains(rule, 'sourceType') ? rule.sourceType : '*'
    destinationAddressPrefix: contains(rule, 'destinationType') ? rule.destinationType : '*'
    destinationPortRange: contains(rule, 'destinationPorts') ? length(rule.destinationPorts) <= 1 ? first(rule.destinationPorts) : null : '*'
    destinationPortRanges: contains(rule, 'destinationPorts') && length(rule.destinationPorts) > 1 ? rule.destinationPorts : []
    sourcePortRange: contains(rule, 'sourcePorts') ? length(rule.sourcePorts) <= 1 ? first(rule.sourcePorts) : null : '*'
    sourcePortRanges: contains(rule, 'sourcePorts') && length(rule.sourcePorts) > 1 ? rule.sourcePorts : []
  }
}]
var securityRules = union(
  inboundRules,
  outboundRules
)

resource azNsgDeployment 'Microsoft.Network/networkSecurityGroups@2023-09-01' = if (empty(securityRules)) {
  name: empty(securityRules) ? formatName(networkSecurityGroupName, affix, environment, region) : 'no-nsg'
  location: networkSecurityGroupLocation
  tags: union(networkSecurityGroupTags, {
      region: region
      environment: environment
    })
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = if (!empty(securityRules)) {
  name: !empty(securityRules) ? formatName(networkSecurityGroupName, affix, environment, region) : 'no-nsg'
  location: networkSecurityGroupLocation
  properties: {
    securityRules: securityRules
  }
  tags: union(networkSecurityGroupTags, {
      region: region
      environment: environment
    })
}

output networkSecurityGroup object = nsg
