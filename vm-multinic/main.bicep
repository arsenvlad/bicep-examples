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

param vmSize string = 'Standard_D8ds_v5'
param location string = resourceGroup().location
param zone string = '1'

@minValue(1)
@maxValue(100)
param instanceCount int = 2

@minValue(1)
@maxValue(8)
param nicCount int = 4

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
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '10.0.0.0/16'
var subnets = [for i in range(0,nicCount): {
  name: 'snet-${i}'
  subnetPrefix: '10.0.${i}.0/24'
}]

var imageReference = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'
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
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
        networkSecurityGroup: {
          id: nsg.id
        }
      }
    }]
  }
}

module vms './vm.bicep' = [for i in range(0, instanceCount): {
  name: 'vms${i}'
  params: {
    location: location
    name: name
    instanceIndex: i
    zone: zone
    vmSize: vmSize
    vnetID: vnet.id
    subnets: subnets
    imageReference: imageReference
    adminUsername: adminUsername
    adminPasswordOrSshPublicKey: adminPasswordOrSshPublicKey
    authenticationType: authenticationType
    linuxConfiguration: linuxConfiguration
    diagStorageAccount: diagStorageAccount
    nicCount: nicCount
  }
}]

