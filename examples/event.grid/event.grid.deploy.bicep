param environment string = 'dev'
param location string = 'est'
param eventGridDomain object


module azEventGridDeploy '../../src/modules/az.event.grid/v1.0/az.event.grid.domain.bicep' ={
  name: 'test-az-eg-domain-deploy'
  params: {
    region: location
    environment: environment
    eventGridDomainName: eventGridDomain.eventGridDomainName
    eventGridDomainLocation: eventGridDomain.eventGridDomainLocation
  }
}
