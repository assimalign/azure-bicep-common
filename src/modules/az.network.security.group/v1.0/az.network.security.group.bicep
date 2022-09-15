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
param networkSecurityGroupName string

@description('')
param networkSecurityGroupLocation string = resourceGroup().location

@description('')
param networkSecurityGroupOutboundRules array = []

@description('')
param networkSecurityGroupInboundRules array = []

@description('')
param networkSecurityGroupTags object = {}

var inboundRules = [for rule in networkSecurityGroupInboundRules: {
  name: rule.name
  properties: {
    direction: 'Inbound'
    protocol: rule.protocol
    access: rule.access
    priority: rule.priority
    description: contains(rule, 'description') ? rule.description : json('null')
    sourceAddressPrefix: contains(rule, 'sourceType') ? rule.sourceType : '*'
    destinationAddressPrefix: contains(rule, 'destinationType') ? rule.destinationType : '*'
    destinationPortRange: contains(rule, 'destinationPorts') ? length(rule.destinationPorts) <= 1 ? first(rule.destinationPorts) : json('null') : '*'
    destinationPortRanges: contains(rule, 'destinationPorts') && length(rule.destinationPorts) > 1 ? rule.destinationPorts : []
    sourcePortRange: contains(rule, 'sourcePorts') ? length(rule.sourcePorts) <= 1 ? first(rule.sourcePorts) : json('null') : '*'
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
    description: contains(rule, 'description') ? rule.description : json('null')
    sourceAddressPrefix: contains(rule, 'sourceType') ? rule.sourceType : '*'
    destinationAddressPrefix: contains(rule, 'destinationType') ? rule.destinationType : '*'
    destinationPortRange: contains(rule, 'destinationPorts') ? length(rule.destinationPorts) <= 1 ? first(rule.destinationPorts) : json('null') : '*'
    destinationPortRanges: contains(rule, 'destinationPorts') && length(rule.destinationPorts) > 1 ? rule.destinationPorts : []
    sourcePortRange: contains(rule, 'sourcePorts') ? length(rule.sourcePorts) <= 1 ? first(rule.sourcePorts) : json('null') : '*'
    sourcePortRanges: contains(rule, 'sourcePorts') && length(rule.sourcePorts) > 1 ? rule.sourcePorts : []
  }
}]
var securityRules = union(
  inboundRules,
  outboundRules
)

resource azNsgDeployment 'Microsoft.Network/networkSecurityGroups@2022-01-01' = if (empty(securityRules)) {
  name: empty(securityRules) ? replace(replace(networkSecurityGroupName, '@environment', environment), '@region', region) : 'no-nsg'
  location: networkSecurityGroupLocation
  tags: union(networkSecurityGroupTags, {
      region: region
      environment: environment
    })
}

resource azNsgWithSecurityRulesDeployment 'Microsoft.Network/networkSecurityGroups@2022-01-01' = if (!empty(securityRules)) {
  name: !empty(securityRules) ? replace(replace(networkSecurityGroupName, '@environment', environment), '@region', region) : 'no-nsg'
  location: networkSecurityGroupLocation
  properties: {
    securityRules: securityRules
  }
  tags: union(networkSecurityGroupTags, {
      region: region
      environment: environment
    })
}
