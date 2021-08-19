# Virtual Machine Scale Set (VMSS) Windows

[![vmss-windows](https://github.com/arsenvlad/bicep-examples/actions/workflows/azure-deploy-vmss-windows.yml/badge.svg)](https://github.com/arsenvlad/bicep-examples/actions/workflows/azure-deploy-vmss-windows.yml)

Deploy Azure Virtual Machine Scale Set into an existing subnet

```bash
az group create --name rg-vmss001 --location eastus2
az deployment group create --resource-group rg-vmss001 --template-file main.bicep --parameter subnetId=/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/rg-prod-core/providers/Microsoft.Network/virtualNetworks/vnet-core-eastus2/subnets/snet-compute -o json --query "properties.outputs"
```

RDP into the VM using NAT Ports

Delete the deployed resource group

```bash
az group delete --resource-group rg-vmss001
```
