// ================ //
// Parameters       //
// ================ //

@description('Required. Config object that contains the resource definitions')
param config object

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

// ================ //
// Resources        //
// ================ //

module virtualNetwork 'modules/virtual-network.bicep' = [for (vnet, index) in config.virtualNetworks: {
  name: vnet.name
  params: {
    name: vnet.name
    tags: vnet.tags
    addressPrefixes: vnet.addressPrefixes
    location: location
    subnets: vnet.subnets
  }
}]
