# Virtual Networks `[Microsoft.Network/virtualNetworks]`

This module deploys Virtual Networks.

## Navigation

- [Virtual Networks `[Microsoft.Network/virtualNetworks]`]
  - [Navigation](#navigation)
  - [ChangeLog](#changelog)
  - [Resource types](#resource-types)
  - [Parameters](#parameters)

## ChangeLog

| Version | Contains breaking changes | Change description  |
| :-- | :-- | :-- |
| 1.0 | No | Added possibility to add tags |
| 0.1 | No | Initial creation of template |

## Resource types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Network/virtualNetworks` | [2023-04-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/2023-02-01/virtualnetworks/subnets?pivots=deployment-language-bicep) |

## Parameters

**Required parameters**

The following parameters are required to call the module

| Parameter Name | Type | Description |
| :-- | :-- | :-- |
| `config` | object | object that contains the resource definitions. |
| `location` | string | `[resourceGroup().location]` |  | Location for all resources. |

add the module to your main bicep file, assumed is that the bicepconfig.json is configured correctly, refer to [bicepconfig.json](../../_starter-resources/bicepconfig.json)

```bicep
module vnet 'br/registry:virtual-network:v1.0' = if(contains(config, 'virtualNetworks')){
  name: 'main-virtual-networks'
  params: {
    location: location
    config: config
  }
}

```

example config.json file

```json
{
  "virtualNetworks": [
    {
      "name": "<CUSTOMERCODE>-<ENVIRONMENT>-vnet", //required
      "tags": { //optional
        "Environment": "DEV",
        "CostCenter": "Development"
      },
      "addressPrefixes": [ //required
          "192.168.0.0/16"
      ],
      "subnets": [ //required
          {
              "name": "<CUSTOMERCODE>-<ENVIRONMENT>-name", // required
              "addressPrefix": "192.168.0.0/20", // required
              "serviceEndpoints": [ //required, if optional specify empty array: "serviceEndpoints": [], 
                  "Microsoft.KeyVault",
                  "Microsoft.ContainerRegistry",
                  "Microsoft.Storage",
                  "Microsoft.Sql"
              ],
              "delegations": [ //required, if optional specify empty array: "delegations": [], 
                {
                  "serviceName": "Microsoft.Sql/servers"
                }
              ], 
              "networkSecurityGroup": "", //required, if none specify: "networkSecurityGroup": ""
              "natGateway": "" //required, if none specify: "natGateway": ""
          }
      ]
    }
  ]
}
```