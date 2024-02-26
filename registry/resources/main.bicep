param config object
param location string = resourceGroup().location

module virtualNetwork 'br/registry:virtual-network:v1.0' = if(contains(config, 'virtualNetworks')){
  name: 'main-virtual-networks'
  params: {
    location: location
    config: config
  }
}
