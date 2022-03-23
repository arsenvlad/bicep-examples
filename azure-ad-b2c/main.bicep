param tenantName string
param displayName string
param location string

resource b2c 'Microsoft.AzureActiveDirectory/b2cDirectories@2021-04-01' = {
  name: tenantName
  location: location
  sku: {
    name: 'PremiumP1'
    tier: 'A0'
  }
  properties: {
    createTenantProperties: {
      displayName: displayName
      countryCode: 'US'
    }
  }
}

output tenantProperties object = b2c
