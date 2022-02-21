# Azure Private Link Service with 2 VMs behind Azure Standard Load Balancer

This template is useful for experimenting with [Azure Private Link Service](https://docs.microsoft.com/azure/private-link/private-link-service-overview)

## Provider

Create Linux VMs behind a public load balancer, install default nginx, and expose them via Azure Private Link Service.

```bash
az group create --name rg-pls001 --location eastus2
az deployment group create --resource-group rg-pls001 --template-file provider/main.bicep --parameter vmSize=Standard_D2s_v5 instanceCount=2 authenticationType=password -o json --query "properties.outputs"
```

## Consumer

Create VNet, private endpoint to the provider's Azure Private Link Service, and a test Linux VM.

```bash
Coming soon
```
