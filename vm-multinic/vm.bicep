param location string
param name string
param instanceIndex int
param zone string
param vmSize string
param vnetID string
param subnets array
param imageReference object
param adminUsername string
@secure()
param adminPasswordOrSshPublicKey string
param authenticationType string
param linuxConfiguration object
param diagStorageAccount object
param nicCount int

var vmName = 'vm${name}${instanceIndex}'
var nicName = 'nic-${vmName}'
var pipName = 'pip-${vmName}'
var dnsLabelPrefix = '${name}-${uniqueString(resourceGroup().id)}'
var publicIPAddress = {
  id: pip.id
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-${instanceIndex}'
    }
  }
}

resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, nicCount): {
  name: '${nicName}-${i}'
  location: location
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnetID}/subnets/${subnets[i].name}'
          }
          publicIPAddress: (i == 0) ? publicIPAddress : json('null')
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
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
      networkInterfaces: [for i in range(0, nicCount): {
          id: nics[i].id
          properties: {
            primary: (i == 0) ? true : false
          }
        }]
    }
    osProfile: {
      computerName: vmName
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
}
