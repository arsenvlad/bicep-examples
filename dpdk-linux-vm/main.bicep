// Parameters
param name string
param adminUsername string = 'azureuser'

@secure()
param adminPassword string

param vmSize string = 'Standard_L8s_v2'
param location string = resourceGroup().location
param zone string = '1'

@minValue(1)
@maxValue(100)
param instanceCount int = 2

// Variables
var dnsLabelPrefix = '${name}-${uniqueString(resourceGroup().id)}'
var pipName = 'pip-${name}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '10.0.0.0/16'
var subnet1Name = 'snet-1'
var subnet1AddressPrefix = '10.0.1.0/24'
var subnet1Id = '${vnet.id}/subnets/${subnet1Name}'
var subnet2Name = 'snet-2'
var subnet2AddressPrefix = '10.0.2.0/24'
var subnet2Id = '${vnet.id}/subnets/${subnet2Name}'
var nic1Name = 'nic1-${name}'
var nic2Name = 'nic2-${name}'
var vmName = 'vm${name}'
var ppgName = 'ppg-${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts'
  version: 'latest'
}

/*
var imageReferenceCentOS = {
  publisher: 'OpenLogic'
  offer: 'CentOS'
  sku: '8_4'
  version: '8.4.2021071900'
}
*/

// Resources
resource ppg 'Microsoft.Compute/proximityPlacementGroups@2021-04-01' = {
  name: ppgName
  location: location
  properties: {
    proximityPlacementGroupType: 'Standard'
  }
}

resource diagStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: diagStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${pipName}${i}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-${i}'
    }
  }
}]

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow_SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: subnet1AddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: subnet2Name
        properties: {
          addressPrefix: subnet2AddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nics1 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nic1Name}${i}'
  location: location
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet1Id
          }
          publicIPAddress: {
            id: pip[i].id
          }
        }
      }
    ]
  }
}]

resource nics2 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nic2Name}${i}'
  location: location
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet2Id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0,instanceCount): {
  name: '${vmName}${i}'
  location: location
  zones: [
    zone
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    proximityPlacementGroup: {
      id: ppg.id
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: imageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics1[i].id
          properties: {
            primary: true
          }
        }
        {
          id: nics2[i].id
          properties: {
            primary: false
          }
        }
      ]
    }
    osProfile: {
      computerName: '${vmName}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]

// Outputs
output fqdn array = [for i in range(0, instanceCount): pip[i].properties.dnsSettings.fqdn]
output ip array = [for i in range(0, instanceCount): pip[i].properties.ipAddress]
