# Azure VMs with 2 NICs in Placement Group

This configuration is useful for experimenting with [DPDK in on Azure Linux VM](https://docs.microsoft.com/en-us/azure/virtual-network/setup-dpdk)

Deploy VMs with 2 NICs in a [Placement Group](https://docs.microsoft.com/en-us/azure/virtual-machines/co-location).

```bash
az group create --name rg-ppg001 --location eastus2
az deployment group create --resource-group rg-ppg001 --template-file main.bicep --parameter vmSize=Standard_L8s_v2 instanceCount=2 -o json --query "properties.outputs"
```

Network interfaces on the VMs

* `eth0` is the management interface (i.e., SSH to this one), has public IP, and Accelerated Networking `disabled`
* `eth1` is the DPDK interface without public IP and with Accelerated Networking `enabled`

SSH into the VMs and install Linux perf tools and DPDK

```bash
sudo apt-get install -y dstat iperf3 fio qperf sockperf
```

Install DPDK (it is usually recommended to [compile from source](https://docs.microsoft.com/en-us/azure/virtual-network/setup-dpdk#compile-and-install-dpdk-manually), but for simple tests we can install via system package manager)

```bash
sudo apt-get install -y dpdk dpdk-dev
```

Configure the runtime environment as [documented](https://docs.microsoft.com/en-us/azure/virtual-network/setup-dpdk).

```bash
echo 1024 | sudo tee /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages
sudo mkdir /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge
sudo grep Huge /proc/meminfo
sudo modprobe -a ib_uverbs
```

Get MAC & IP address for eth1

```bash
ifconfig -a
```

Get PCI bus id for the VF interface (usually starts with en*)

```bash
ethtool -i <vf interface name>
```

Run on `sender` (change the parameters to proper values)

```bash
sudo dpdk-testpmd \
  -l 0,1 \
  -n 1 \
  -w f8d6:00:02.0 \
  --vdev="net_vdev_netvsc0,iface=eth1" \
  -- --port-topology=chained \
  --nb-cores 1 \
  --forward-mode=txonly \
  --tx-ip=10.0.2.4,10.0.2.5 \
  --stats-period 1
```

Run on `receiver` (change the parameters to proper values)

```bash
sudo dpdk-testpmd \
  -l 0,1 \
  -n 1 \
  -w deae:00:02.0 \
  --vdev="net_vdev_netvsc0,iface=eth1" \
  -- --port-topology=chained \
  --nb-cores 1 \
  --forward-mode=rxonly \
  --tx-ip=10.0.2.4,10.0.2.5 \
  --stats-period 1
```

Delete the deployed resource group

```bash
az group delete --resource-group rg-ppg001
```
