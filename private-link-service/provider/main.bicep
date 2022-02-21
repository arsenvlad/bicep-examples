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
param instanceCount int = 2

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
var vnetAddressPrefix = '10.0.0.0/16'
var subnet1Name = 'snet-1'
var subnet1AddressPrefix = '10.0.1.0/24'
var subnet1Id = '${vnet.id}/subnets/${subnet1Name}'
var subnet2Name = 'snet-2'
var subnet2AddressPrefix = '10.0.2.0/24'
var subnet2Id = '${vnet.id}/subnets/${subnet2Name}'
var lbName = 'lb-${name}'
var nicName = 'nic-${name}'
var vmName = 'vm${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'
var plsName = 'pls-${name}'

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

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${pipName}-plb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-plb'
    }
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
        name: 'Allow_HTTP'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow_HTTPS'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
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
          privateLinkServiceNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    // Public Load Balancer (to use private load balancer, we would specify subnet instead of public IP)
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: pip.id
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
        name: 'lb_http'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 30
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'probe_http')
          }
        }
      }
      {
        name: 'lb_https'
        properties: {
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          idleTimeoutInMinutes: 30
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe_http'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource inboundNatRules 'Microsoft.Network/loadBalancers/inboundNatRules@2021-05-01' = [for i in range(0, instanceCount): {
  name: 'nat_ssh_${i}'
  parent: loadBalancer
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendIpConfig')
    }
    protocol: 'Tcp'
    frontendPort: (i+50000)
    backendPort: 22
  }
}]

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
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancer.properties.backendAddressPools[0].id
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: inboundNatRules[i].id
            }
          ]
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
      commandToExecute: 'sudo apt update && sleep 10 && sudo apt install -y nginx'
    }
  }
}]

resource pls 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: plsName
  location: location
  properties: {
    // TCP Proxy v2 protocol (https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt)
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendIpConfig') 
      }
    ]
    // NAT IP configurations (up to 8 for scaling ports beyond 64K per IP + backend VM combination)
    ipConfigurations: [for i in range(0,8): {
        name: '${subnet2Name}-nat${i}'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnet2Id
          }
          primary: (i == 0) ? true : false
        }
      }]
  }
}

// Outputs
output fqdn string = pip.properties.dnsSettings.fqdn
output ip string = pip.properties.ipAddress
