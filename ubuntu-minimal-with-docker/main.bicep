// Parameters
param location string = resourceGroup().location
param name string

@secure()
param adminUsername string = 'azureuser'
param adminPassword string

// Variables
var dnsLabelname = '${name}-${uniqueString(resourceGroup().id)}'
var pipName = 'pip-${name}'
var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'
var vnetAddressPrefix = '10.0.0.0/16'
var subnetName = 'snet-default'
var subnetAddressPrefix = '10.0.0.0/24'
var subnetId = '${vnet.id}/subnets/${subnetName}'
var nicName = 'nic-${name}'
var vmName = 'vm${name}'
var vmSize = 'Standard_DS2_v2'

// Multiline string with cloud-init directives to install docker on the VM by passing it as base64 encoding string to customData
var cloudInit = '''
#cloud-config
package_update: true

packages:
    - apt-transport-https
    - ca-certificates
    - curl
    - gnupg
    - lsb-release

runcmd:
    - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io
'''

// Resources
resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
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
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-minimal-hirsute-daily'
        sku: 'minimal-21_04-daily'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInit)
    }
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    dnsSettings: {
      domainNameLabel: dnsLabelname
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
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

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
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

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
  }
}

// Outputs
output hostname string = publicIP.properties.dnsSettings.fqdn
