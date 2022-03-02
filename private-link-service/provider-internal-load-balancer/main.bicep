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
var subnetBastionName = 'AzureBastionSubnet'
var subnetBastionAddressPrefix = '10.0.254.0/26'
var subnetBastionId = '${vnet.id}/subnets/${subnetBastionName}'
var lbName = 'lb-${name}'
var nicName = 'nic-${name}'
var vmName = 'vm${name}'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'
var plsName = 'pls-${name}'
var bastionName = 'bastion-${name}'
var ngwName = 'ngw-${name}'

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

resource pipBastion 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${pipName}-bastion'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-bastion'
    }
  }
}

resource pipNatGateway 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${pipName}-ngw'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-ngw'
    }
  }
}


resource natGateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: ngwName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: pipNatGateway.id
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
        name: 'Allow_SSH_AzureBastionSubnet'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: subnetBastionAddressPrefix
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
          natGateway: {
            id: natGateway.id
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
      {
        name: subnetBastionName
        properties: {
          addressPrefix: subnetBastionAddressPrefix
        }
      }
    ]
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    scaleUnits: 2
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          publicIPAddress: {
            id: pipBastion.id
          }
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetBastionId
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
    // Internal Load Balancer (to use public load balancer, we would specify public IP instead of subnet)
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnet1Id
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
          disableOutboundSnat: true
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

resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, instanceCount): {
  name: '${nicName}${i}'
  location: location
  dependsOn: [
    loadBalancer
    natGateway
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
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool')
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

// Azure Private Link Service
resource pls 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: plsName
  location: location
  dependsOn: [
    loadBalancer
  ]
  properties: {
    // TCP Proxy v2 protocol (https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt)
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendIpConfig')
      }
    ]
    // NAT IP configurations (up to 8 for scaling ports beyond 64K per IP + backend VM combination)
    ipConfigurations: [for i in range(0, 8): {
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
    // Visible to any Azure subscription that has the alias
    visibility: {
      subscriptions: [
        '*'
      ]
    }
    autoApproval: {
      subscriptions: [
        
      ]
    }
  }
}

// Outputs
output loadBalancerIp string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
output alias string = pls.properties.alias
