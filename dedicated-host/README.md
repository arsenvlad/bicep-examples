# Azure VMs with 3 NICs on Azure Dedicated Host

Deploy VMs with 3 NICs in a [Azure Dedicated Host Group](https://learn.microsoft.com/azure/virtual-machines/dedicated-hosts).

```bash
az group create --name rg-dh1 --location eastus

az vm host group create --resource-group rg-dh1 --name dhg1 --location eastus --automatic-placement true --platform-fault-domain-count 2
az vm host create --resource-group rg-dh1 --name dh1 --host-group dhg1 --sku Lsv3-Type1 --auto-replace false --location eastus --platform-fault-domain 0

az deployment group create --name d1 --resource-group rg-dh1 --template-file main.bicep --parameter hostId=/subscriptions/<subId>/resourceGroups/rg-dh1/providers/Microsoft.Compute/hostGroups/dhg1/hosts/dh1 vmSize=Standard_L8s_v3 instanceCount=6 authenticationType=password diskSize=70 name=dhv1 -o json --query "properties.outputs"
```
