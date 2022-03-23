# Azure AD B2C Directory

Create resource group and Azure AD B2C tenant resource using Bicep template

```bash
az group create --name rg-aadb2c03 --location eastus2

az deployment group create --resource-group rg-aadb2c03 --template-file main.bicep --parameters tenantName="avtenant03.onmicrosoft.com" location="United States" displayName="AV Tenant 03" -o json
```

Azure AD B2C resource creation output properties

```json
{
    "tenantProperties": {
    "type": "Object",
    "value": {
        "apiVersion": "2021-04-01",
        "condition": true,
        "existing": false,
        "isAction": false,
        "isConditionTrue": true,
        "isTemplateResource": false,
        "location": "United States",
        "properties": {
        "billingConfig": {
            "billingType": "MAU",
            "effectiveStartDateUtc": "1/1/0001 12:00:00 AM"
        },
        "tenantId": "2b188e52-11a9-42c4-a83b-6d3822567597"
        },
        "provisioningOperation": "Read",
        "referenceApiVersion": "2021-04-01",
        "resourceGroupName": "rg-aadb2c03",
        "resourceId": "Microsoft.AzureActiveDirectory/b2cDirectories/avtenant03.onmicrosoft.com",
        "scope": "",
        "sku": {
        "name": "PremiumP1",
        "tier": "A0"
        },
        "subscriptionId": "c9c8ae57-acdb-48a9-99f8-d57704f18dee"
    }
    }
}
```
