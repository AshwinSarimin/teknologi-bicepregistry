param config object
param location string = resourceGroup().location

module virtualNetwork 'br/registry:virtual-network:v0.4' = if(contains(config, 'virtualNetworks')){
  name: 'main-virtual-networks'
  params: {
    location: location
    config: config
  }
  dependsOn: [
    networkSecurityGroup
  ]
}
