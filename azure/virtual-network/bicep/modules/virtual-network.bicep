param name string
param tags object
param location string
param addressPrefixes array
param subnets array

resource getNsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' existing = [for subnet in subnets: {
  name: subnet.networkSecurityGroup
}]

resource getGateway 'Microsoft.Network/natGateways@2023-04-01' existing = [for subnet in subnets: {
  name: subnet.natGateway
}]

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [for (subnet, idx) in subnets: {
      name: subnet.name
      properties: union({ 
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: map(subnet.serviceEndpoints, serviceEndpoint => {
          service: serviceEndpoint
        })
      }, (empty(subnet.delegations)) ? {} : {
        delegations: map(range(0, length(subnet.delegations)), i => {
          name: replace(string(subnet.delegations[i].serviceName), '/', '.')
          properties: {
            serviceName: subnet.delegations[i].serviceName
          }
        })
      }, (empty(subnet.networkSecurityGroup)) ? {} : {
          networkSecurityGroup: {
            id: getNsg[idx].id
          }
        }, (empty(subnet.natGateway)) ? {} : {
          natGateway: {
            id: getGateway[idx].id
          }
        })
    }]
  }
}
