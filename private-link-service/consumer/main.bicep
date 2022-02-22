// Parameters
param name string
param adminUsername string = 'azureuser'

@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@secure()
param adminPasswordOrSshPublicKey string

param vmSize string = 'Standard_D2s_v5'
param location string = resourceGroup().location
param zone string = '1'

@minValue(1)
@maxValue(100)
param instanceCount int = 1

param privateLinkServiceId string
param privateLinkServiceRequestMessage string = 'My test private link service connection "${name}"'

// Variables
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrSshPublicKey
      }
    ]
  }
}
var dnsLabelPrefix = '${name}-${uniqueString(resourceGroup().id)}'
var pipName = 'pip-${name}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '172.16.0.0/16'
var subnet1Name = 'snet-1'
var subnet1AddressPrefix = '172.16.1.0/24'
var subnet1Id = '${vnet.id}/subnets/${subnet1Name}'
var nicName = 'nic-${name}'
var vmName = 'vm${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'
var peName = 'pe-${name}'

var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts'
  version: 'latest'
}

// Resources
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
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, instanceCount): {
  name: '${nicName}${i}'
  location: location
  properties: {
    enableAcceleratedNetworking: true
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

resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, instanceCount): {
  name: '${vmName}${i}'
  location: location
  zones: [
    zone
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          id: nics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      computerName: '${vmName}${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrSshPublicKey
      linuxConfiguration: any(authenticationType == 'password' ? null : linuxConfiguration)
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]

resource customScripts 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for i in range(0, instanceCount): {
  name: 'customScript'
  location: location
  parent: vms[i]
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {}
    protectedSettings: {
      commandToExecute: 'sudo apt update && sleep 10 && ip addr'
    }
  }
}]

// Private Endpoint
resource pe 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: subnet1Id
    }
    manualPrivateLinkServiceConnections: [
      {
        name: peName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          requestMessage: privateLinkServiceRequestMessage
        }
      }
    ]
  }
}

// Outputs
output pe_nic_id string = pe.properties.networkInterfaces[0].id
output consumer_vm_fqdn array = [for i in range(0, instanceCount): pip[i].properties.dnsSettings.fqdn]
output consumer_vm_ip array = [for i in range(0, instanceCount): pip[i].properties.ipAddress]

