# Azure Load Balancer HA Ports

Deploy Azure Load Balancer with Public IP frontend and HA Ports

```bash
az group create --name rg-lbha001 --location eastus2
az deployment group create --resource-group rg-lbha001 --template-file main.bicep -o json --query "properties.outputs"
```

The template creates 2 VMs and starts background "netcat" listening on UDP port 50000 that logs into /tmp/nc.log file

SSH into the VMs and check the log file which should be empty

```bash
tail -f /tmp/nc.log
```

Now, try connecting to the UDP port 50000 of the load balancer public inbound IP and send some data

```bash
nc -u 40.75.125.29 50000
hello
world
!
Ctrl+C
```

Check the output of the tail command above to see which of the VMs received the traffic

Delete the deployed resource group

```bash
az group delete --resource-group rg-lbha001
```
