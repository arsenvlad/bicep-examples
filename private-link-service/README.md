# Azure Private Link Service with 2 VMs behind Azure Standard Load Balancer

This template is useful for experimenting with [Azure Private Link Service](https://docs.microsoft.com/azure/private-link/private-link-service-overview)

## Provider

Create a resource group for the Private Link Service (PLS).

Create Linux VMs behind a public load balancer, install default nginx, and expose them via Azure Private Link Service.

```bash
az group create --name rg-pls001 --location eastus2
az deployment group create --resource-group rg-pls001 --template-file provider/main.bicep --parameter vmSize=Standard_D2s_v5 instanceCount=2 authenticationType=password -o json --query "properties.outputs"
```

Get `alias` value to use as the privateLinkServiceId parameter when creating the consumer deployment.

## Consumer

Consumer is usually using different Azure subscription and Azure Active Directory tenant than the provider.

Create a resource group for the Private Endpoint (PE).

Create VNet, private endpoint to the provider's Azure Private Link Service (need `alias` for the privateLinkServiceId parameter), and a test Linux VM.

```bash
az group create --name rg-pe001 --location westus2
az deployment group create --resource-group rg-pe001 --template-file consumer/main.bicep --parameter vmSize=Standard_D2s_v5 instanceCount=1 authenticationType=password -o json --query "properties.outputs"
```

Get private endpoint IP address

```bash
az resource show --id pe_nic_id --query 'properties.ipConfigurations[*].properties.privateIPAddress'
```

SSH into the consumer VM and test connection to provider using curl

```bash
ssh azureuser@consumer_vm_fqdn

curl http://private_endpoint_ip_address
```
