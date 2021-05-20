# Ubuntu Minimal with Docker

Deploy Azure VM with Ubuntu Minimal OS and Docker

```bash
az group create --name rg-ubuntuminimal --location eastus2
az deployment group create --resource-group rg-ubuntuminimal --template-file ubuntu-minimal.bicep -o json
```

SSH into the VM

```bash
ssh azureuser@{fqdn of the VM}
```

Check that docker is installed

```bash
docker version
```
