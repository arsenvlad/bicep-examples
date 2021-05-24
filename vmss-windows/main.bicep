// Parameters
param name string
param subnetId string
param adminUsername string = 'azureuser'

@secure()
param adminPassword string

param vmSize string = 'Standard_DS2_v2'
param location string = resourceGroup().location

@minValue(1)
@maxValue(100)
param instanceCount int

// Variables
var dnsLabelPrefix = '${name}-${uniqueString(resourceGroup().id)}'
var nicName = 'nic-${name}'
var vmssName = 'vmss${name}'
var lbName = 'lb-${name}'
var pipName = 'pip-${name}'
var imageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}

// Resources
resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: lbName
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontEndIpConfig'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]
    inboundNatPools: [
      {
        name: 'natPool'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontEndIpConfig')
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 50000
          frontendPortRangeEnd: 50100
          backendPort: 3389
        }
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: vmssName
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: name
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipConfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: loadBalancer.properties.backendAddressPools[0].id
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: loadBalancer.properties.inboundNatPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// Outputs
output fqdn string = publicIP.properties.dnsSettings.fqdn
