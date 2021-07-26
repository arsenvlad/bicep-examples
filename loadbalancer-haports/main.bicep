// Parameters
param name string
param adminUsername string = 'azureuser'

@secure()
param adminPassword string

param vmSize string = 'Standard_DS2_v2'
param location string = resourceGroup().location

@minValue(1)
@maxValue(100)
param instanceCount int = 2

// Variables
var dnsLabelPrefix = '${name}-${uniqueString(resourceGroup().id)}'
var lbName = 'lb-${name}'
var pipNameInbound = 'pip-${name}'
var pipNameOutbound = 'pipoutbound-${name}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '10.0.0.0/16'
var subnetName = 'snet-default'
var subnetAddressPrefix = '10.0.0.0/24'
var subnetId = '${vnet.id}/subnets/${subnetName}'
var nicName = 'nic-${name}'
var avsetName = 'avset-${name}'
var vmName = 'vm${name}'
var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts'
  version: 'latest'
}

// Multiline string with cloud-init directives
var cloudInit = '''
#cloud-config
package_update: true

packages:
    - netcat

runcmd:
    - nohup nc -lu 50000 > /tmp/nc.log &
'''

// Resources
resource pipInbound 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: pipNameInbound
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource pipOutbound 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: pipNameOutbound
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendInbound'
        properties: {
          publicIPAddress: {
            id: pipInbound.id
          }
        }
      }
      {
        name: 'frontendOutbound'
        properties: {
          publicIPAddress: {
            id: pipOutbound.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'tcp_haports'
        properties: {
            protocol: 'Tcp'
            frontendPort: 0
            backendPort: 0
            disableOutboundSnat: true
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendInbound')
            }
            backendAddressPool: {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
            }
        }
      }
      {
        name: 'udp_haports'
        properties: {
            protocol: 'Udp'
            frontendPort: 0
            backendPort: 0
            disableOutboundSnat: true
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendInbound')
            }
            backendAddressPool: {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
            }
        }
      }
    ]
    outboundRules: [
      {
        name: 'outbound'
        properties: {
          protocol: 'All'
          enableTcpReset: true
          allocatedOutboundPorts: 10000
          idleTimeoutInMinutes: 4
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendOutbound')
            }
          ]
        }
      }
    ]
  }
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
      {
        name: 'Allow_AllTcp'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow_AllUdp'
        properties: {
          priority: 1020
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
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
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0,instanceCount): {
  name: '${nicName}${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancer.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
}]

resource avset 'Microsoft.Compute/availabilitySets@2021-03-01' = {
  name: avsetName
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}

resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0,instanceCount): {
  name: '${vmName}${i}'
  location: location
  properties: {
    availabilitySet: {
      id: avset.id
    }
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
        }
      ]
    }
    osProfile: {
      computerName: '${vmName}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInit)
    }
  }
}]

// Outputs
output fqdnInbound string = pipInbound.properties.dnsSettings.fqdn
output ipInbound string = pipInbound.properties.ipAddress
output ipOutbound string = pipOutbound.properties.ipAddress
