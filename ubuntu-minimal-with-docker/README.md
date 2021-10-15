# Ubuntu Minimal with Docker

Deploy Azure VM with Ubuntu Minimal OS and Docker

```bash
az group create --name rg-ubuntuminimal --location eastus2
az deployment group create --resource-group rg-ubuntuminimal --template-file main.bicep -o json --query "properties.outputs"
```

SSH into the VM

```bash
ssh azureuser@{FQDN_OF_THE_DEPLOYED_VM}
```

Check that docker is installed properly

```bash
docker version
```
 