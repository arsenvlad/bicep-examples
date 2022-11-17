param name string
param adminUsername string = 'azureuser'
param subnet1Id string
param subnet2Id string
param subnet3Id string

@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@secure()
param adminPasswordOrSshPublicKey string

param vmSize string = 'Standard_D8ds_v5'
param location string = resourceGroup().location

@minValue(1)
@maxValue(100)
param instanceCount int = 2
param diskSize int = 30

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
var nic1Name = 'nic1-${name}'
var nic2Name = 'nic2-${name}'
var nic3Name = 'nic3-${name}'
var vmName = 'vm${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

var imageReference = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'
  version: '18.04.202204190'
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

@batchSize(1)
resource nics1 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nic1Name}${i}'
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

@batchSize(1)
resource nics2 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nic2Name}${i}'
  location: location
  dependsOn: [
    nics1
  ]
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

@batchSize(1)
resource nics3 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nic3Name}${i}'
  location: location
  dependsOn: [
    nics2
  ]
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet3Id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0,instanceCount): {
  name: '${vmName}${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        diskSizeGB: diskSize
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diffDiskSettings: {
          option: 'Local'
          placement: 'ResourceDisk'
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
        {
          id: nics3[i].id
          properties: {
            primary: false
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
    settings: {
      script: loadFileAsBase64('init.sh')
    }
  }
}]

// Outputs
output fqdn array = [for i in range(0, instanceCount): pip[i].properties.dnsSettings.fqdn]
output ip array = [for i in range(0, instanceCount): pip[i].properties.ipAddress]
