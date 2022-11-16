# Azure VMs with 3 NICs on Azure Dedicated Host

Deploy VMs with 3 NICs in a [Azure Dedicated Host Group](https://learn.microsoft.com/azure/virtual-machines/dedicated-hosts).

```bash
# Create resource group
az group create --name rg-dh3 --location eastus

# Deploy VMs on dedicated host
az deployment group create --name d1 --resource-group rg-dh3 --template-file main.bicep --parameter dedicatedHostSku=Lsv3-Type1 vmSize=Standard_L8s_v3 instanceCount=6 authenticationType=password diskSize=80 name=dhv1 -o json --query "properties.outputs"
```
