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
var applicationGatewayName = 'appgw-${name}'
var pipName = 'pip-${name}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '10.0.0.0/16'
var subnet1Name = 'snet-vms'
var subnet1AddressPrefix = '10.0.1.0/24'
var subnet1Id = '${vnet.id}/subnets/${subnet1Name}'
var subnet2Name = 'snet-appgw'
var subnet2AddressPrefix = '10.0.2.0/24'
var subnet2Id = '${vnet.id}/subnets/${subnet2Name}'
var subnet3Name = 'snet-privatelinknat'
var subnet3AddressPrefix = '10.0.3.0/24'
var subnet3Id = '${vnet.id}/subnets/${subnet3Name}'
var nicName = 'nic-${name}'
var vmName = 'vm${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts'
  version: 'latest'
}

// Multiline string with installation script
// Configure NGINX to output server address, remote address, and TCP Proxy v2 address
var installScript = '''
#!/bin/bash
sleep 30
sudo apt update
sleep 10
sudo apt install -y nginx
sudo mv /etc/nginx/nginx.conf /etc/nging/nginx.conf.backup
sudo bash -c 'cat > /etc/nginx/nginx.conf' <<EOL
events { }
http {
    server {
      listen 80;
      location / {
        add_header Content-Type text/html;
        return 200 '<html><body>server_addr=\$server_addr<br>remote_addr=\$remote_addr<br>x_forwarded_for=\$proxy_add_x_forwarded_for<br>proxy_protocol_addr=\$proxy_protocol_addr</body></html>';
      }
    }
}
EOL
sudo systemctl restart nginx
'''

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
        name: 'Allow_ApplicationGateway'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '65200-65535'
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
      {
        name: subnet3Name
        properties: {
          addressPrefix: subnet3AddressPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource appgw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet2Id
          }
        }
      }
    ]
    privateLinkConfigurations: [
      {
        name: 'privatelinkconfig1'
        properties: {
          // NAT IP configurations (up to 8 for scaling ports beyond 64K per IP)
          ipConfigurations: [for i in range(0, 8): {
            name: 'nat${i}'
            properties: {
              privateIPAllocationMethod: 'Dynamic'
              subnet: {
                id: subnet3Id
              }
              primary: (i == 0) ? true : false
            }
          }]
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontend1'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
          privateLinkConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations', applicationGatewayName, 'privatelinkconfig1')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendpool1'
        properties: {
          backendAddresses: []
        }
      }
    ]
    probes: [
      {
        name: 'http'
        properties: {
          protocol: 'Http'
          host: '127.0.0.1'
          port: 80
          path: '/'
          interval: 5
          timeout: 10
          unhealthyThreshold: 2
          minServers: 0
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'backendhttpsettings1'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          probeEnabled: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, 'http')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httplistener1'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'frontend1')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'http')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule1'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'httplistener1')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'backendpool1')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'backendhttpsettings1')
          }
        }
      }
    ]
  }
}

resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, instanceCount): {
  name: '${nicName}${i}'
  location: location
  dependsOn: [
    appgw
  ]
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
          applicationGatewayBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'backendPool1')
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
    settings: {
      script: base64(installScript)
    }
  }
}]

// Outputs
output fqdn string = pip.properties.dnsSettings.fqdn
output ip string = pip.properties.ipAddress
