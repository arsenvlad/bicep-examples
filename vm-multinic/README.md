# Azure VMs with Multiple NICs

This sample template is useful for creating multiple VMs each with multiple NICs in the same VNet.

## Create VMs with multiple NICs each

Create 2 VMs with 4 NICs each

```bash
az group create --name rg-multinic1 --location eastus2
az deployment group create --resource-group rg-multinic1 --template-file main.bicep --parameter vmSize=Standard_D8ds_v5 instanceCount=2 nicCount=4 authenticationType=password -o json --query "properties.outputs"
```

## Network interfaces on the VMs

SSH into the VM: `ssh azureuser@PUBLIC_IP_OF_THE_VM`

List network interfaces on the VMs. Ethernet interface names eth0, eth1, eth2, and eth3 map to the order that NICs are attached to the VM. This order is preserved across reboots.

```bash
ip addr

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000  
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:03:16:46 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.5/24 brd 10.0.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe03:1646/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:03:1e:b1 brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.5/24 brd 10.0.1.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe03:1eb1/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:03:18:c9 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.4/24 brd 10.0.2.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe03:18c9/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:03:19:f7 brd ff:ff:ff:ff:ff:ff
    inet 10.0.3.5/24 brd 10.0.3.255 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe03:19f7/64 scope link 
       valid_lft forever preferred_lft forever
6: enP14549s4: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth3 state UP group default qlen 1000
    link/ether 00:0d:3a:03:19:f7 brd ff:ff:ff:ff:ff:ff
7: enP2969s1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth0 state UP group default qlen 1000
    link/ether 00:0d:3a:03:16:46 brd ff:ff:ff:ff:ff:ff
8: enP41635s2: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth1 state UP group default qlen 1000
    link/ether 00:0d:3a:03:1e:b1 brd ff:ff:ff:ff:ff:ff
9: enP12161s3: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth2 state UP group default qlen 1000
    link/ether 00:0d:3a:03:18:c9 brd ff:ff:ff:ff:ff:ff
```

Because these VMs are created with Accelerated Networking enabled, we can see the Ethernet controller devices using `lspci`. However, we cannot reliably use the hardware ids since they will change if VM is stopped-deallocated or live-migrated to another host.

```text
azureuser@vmav0:~$ lspci

0000:00:00.0 Host bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (AGP disabled) (rev 03)
0000:00:07.0 ISA bridge: Intel Corporation 82371AB/EB/MB PIIX4 ISA (rev 01)
0000:00:07.1 IDE interface: Intel Corporation 82371AB/EB/MB PIIX4 IDE (rev 01)
0000:00:07.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI (rev 02)
0000:00:08.0 VGA compatible controller: Microsoft Corporation Hyper-V virtual VGA
0b99:00:02.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function] (rev 80)
2f81:00:02.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function] (rev 80)
38d5:00:02.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function] (rev 80)
a2a3:00:02.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function] (rev 80)
```

We can also see the mapping between the  bus info and the PCI devices via `lshw -c network -businfo`

```text
azureuser@vmav0:~$ lshw -c network -businfo
WARNING: you should run this program as super-user.
Bus info          Device      Class      Description
====================================================
pci@0b99:00:02.0  enP2969s1   network    MT27800 Family [ConnectX-5 Virtual Function]
pci@2f81:00:02.0  enP12161s3  network    MT27800 Family [ConnectX-5 Virtual Function]
pci@38d5:00:02.0  enP14549s4  network    MT27800 Family [ConnectX-5 Virtual Function]
pci@a2a3:00:02.0  enP41635s2  network    MT27800 Family [ConnectX-5 Virtual Function]
                  eth1        network    Ethernet interface
                  eth0        network    Ethernet interface
                  eth2        network    Ethernet interface
                  eth3        network    Ethernet interface
```

Non-verbose output of `lsvmbus` looks like the following and does not include Device_ID, but shows that there are 4 `Synthetic network adapters`:

```text
azureuser@vmav0:~$ lsvmbus
VMBUS ID  1: [Dynamic Memory]
VMBUS ID  2: Synthetic IDE Controller
VMBUS ID  3: Synthetic IDE Controller
VMBUS ID  4: Synthetic mouse
VMBUS ID  5: Synthetic keyboard
VMBUS ID  6: Synthetic framebuffer adapter
VMBUS ID  7: [Heartbeat]
VMBUS ID  8: [Data Exchange]
VMBUS ID  9: [Operating system shutdown]
VMBUS ID 10: [Time Synchronization]
VMBUS ID 11: Synthetic network adapter
VMBUS ID 12: Synthetic network adapter
VMBUS ID 13: Synthetic network adapter
VMBUS ID 14: Synthetic network adapter
VMBUS ID 15: Synthetic SCSI Controller
VMBUS ID 16: Synthetic SCSI Controller
VMBUS ID 47: PCI Express pass-through
VMBUS ID 48: PCI Express pass-through
VMBUS ID 49: PCI Express pass-through
VMBUS ID 50: PCI Express pass-through
```

Verbose output of `lsvmbus -vv` looks like the following and includes the `Device_ID` and `Sysfs path` values for each of the devices:

```text
azureuser@vmav0:~$ lsvmbus -vv
VMBUS ID  1: Class_ID = {525074dc-8985-46e2-8057-a307dc18a502} - [Dynamic Memory]        
        Device_ID = {1eccfd72-4b41-45ef-b73a-4a6e44c12924}
        Sysfs path: /sys/bus/vmbus/devices/1eccfd72-4b41-45ef-b73a-4a6e44c12924
        Rel_ID=1, target_cpu=0

VMBUS ID  2: Class_ID = {32412632-86cb-44a2-9b5c-50d1417354f5} - Synthetic IDE Controller
        Device_ID = {00000000-0000-8899-0000-000000000000}
        Sysfs path: /sys/bus/vmbus/devices/00000000-0000-8899-0000-000000000000
        Rel_ID=2, target_cpu=0

VMBUS ID  3: Class_ID = {32412632-86cb-44a2-9b5c-50d1417354f5} - Synthetic IDE Controller
        Device_ID = {00000000-0001-8899-0000-000000000000}
        Sysfs path: /sys/bus/vmbus/devices/00000000-0001-8899-0000-000000000000
        Rel_ID=3, target_cpu=1

VMBUS ID  4: Class_ID = {cfa8b69e-5b4a-4cc0-b98b-8ba1a1f3f95a} - Synthetic mouse
        Device_ID = {58f75a6d-d949-4320-99e1-a2a2576d581c}
        Sysfs path: /sys/bus/vmbus/devices/58f75a6d-d949-4320-99e1-a2a2576d581c
        Rel_ID=4, target_cpu=0

VMBUS ID  5: Class_ID = {f912ad6d-2b17-48ea-bd65-f927a61c7684} - Synthetic keyboard
        Device_ID = {d34b2567-b9b6-42b9-8778-0a4ec0b955bf}
        Sysfs path: /sys/bus/vmbus/devices/d34b2567-b9b6-42b9-8778-0a4ec0b955bf
        Rel_ID=5, target_cpu=0

VMBUS ID  6: Class_ID = {da0a7802-e377-4aac-8e77-0558eb1073f8} - Synthetic framebuffer adapter
        Device_ID = {5620e0c7-8062-4dce-aeb7-520c7ef76171}
        Sysfs path: /sys/bus/vmbus/devices/5620e0c7-8062-4dce-aeb7-520c7ef76171
        Rel_ID=6, target_cpu=0

VMBUS ID  7: Class_ID = {57164f39-9115-4e78-ab55-382f3bd5422d} - [Heartbeat]
        Device_ID = {fd149e91-82e0-4a7d-afa6-2a4166cbd7c0}
        Sysfs path: /sys/bus/vmbus/devices/fd149e91-82e0-4a7d-afa6-2a4166cbd7c0
        Rel_ID=7, target_cpu=0

VMBUS ID  8: Class_ID = {a9a0f4e7-5a45-4d96-b827-8a841e8c03e6} - [Data Exchange]
        Device_ID = {242ff919-07db-4180-9c2e-b86cb68c8c55}
        Sysfs path: /sys/bus/vmbus/devices/242ff919-07db-4180-9c2e-b86cb68c8c55
        Rel_ID=8, target_cpu=0

VMBUS ID  9: Class_ID = {0e0b6031-5213-4934-818b-38d90ced39db} - [Operating system shutdown]
        Device_ID = {b6650ff7-33bc-4840-8048-e0676786f393}
        Sysfs path: /sys/bus/vmbus/devices/b6650ff7-33bc-4840-8048-e0676786f393
        Rel_ID=9, target_cpu=0

VMBUS ID 10: Class_ID = {9527e630-d0ae-497b-adce-e80ab0175caf} - [Time Synchronization]
        Device_ID = {2dd1ce17-079e-403c-b352-a1921ee207ee}
        Sysfs path: /sys/bus/vmbus/devices/2dd1ce17-079e-403c-b352-a1921ee207ee
        Rel_ID=10, target_cpu=0

VMBUS ID 11: Class_ID = {f8615163-df3e-46c5-913f-f2d2f965ed0e} - Synthetic network adapter
        Device_ID = {000d3a03-1646-000d-3a03-1646000d3a03}
        Sysfs path: /sys/bus/vmbus/devices/000d3a03-1646-000d-3a03-1646000d3a03
        Rel_ID=11, target_cpu=2
        Rel_ID=19, target_cpu=3
        Rel_ID=20, target_cpu=4
        Rel_ID=21, target_cpu=5
        Rel_ID=22, target_cpu=6
        Rel_ID=23, target_cpu=7
        Rel_ID=24, target_cpu=1
        Rel_ID=25, target_cpu=0

VMBUS ID 12: Class_ID = {f8615163-df3e-46c5-913f-f2d2f965ed0e} - Synthetic network adapter
        Device_ID = {000d3a03-1eb1-000d-3a03-1eb1000d3a03}
        Sysfs path: /sys/bus/vmbus/devices/000d3a03-1eb1-000d-3a03-1eb1000d3a03
        Rel_ID=12, target_cpu=3
        Rel_ID=26, target_cpu=1
        Rel_ID=27, target_cpu=2
        Rel_ID=28, target_cpu=4
        Rel_ID=29, target_cpu=5
        Rel_ID=30, target_cpu=6
        Rel_ID=31, target_cpu=7
        Rel_ID=32, target_cpu=0

VMBUS ID 13: Class_ID = {f8615163-df3e-46c5-913f-f2d2f965ed0e} - Synthetic network adapter
        Device_ID = {000d3a03-18c9-000d-3a03-18c9000d3a03}
        Sysfs path: /sys/bus/vmbus/devices/000d3a03-18c9-000d-3a03-18c9000d3a03
        Rel_ID=13, target_cpu=4
        Rel_ID=33, target_cpu=1
        Rel_ID=34, target_cpu=2
        Rel_ID=35, target_cpu=3
        Rel_ID=36, target_cpu=5
        Rel_ID=37, target_cpu=6
        Rel_ID=38, target_cpu=7
        Rel_ID=39, target_cpu=0

VMBUS ID 14: Class_ID = {f8615163-df3e-46c5-913f-f2d2f965ed0e} - Synthetic network adapter
        Device_ID = {000d3a03-19f7-000d-3a03-19f7000d3a03}
        Sysfs path: /sys/bus/vmbus/devices/000d3a03-19f7-000d-3a03-19f7000d3a03
        Rel_ID=14, target_cpu=5
        Rel_ID=40, target_cpu=1
        Rel_ID=41, target_cpu=2
        Rel_ID=42, target_cpu=3
        Rel_ID=43, target_cpu=4
        Rel_ID=44, target_cpu=6
        Rel_ID=45, target_cpu=7
        Rel_ID=46, target_cpu=0

VMBUS ID 15: Class_ID = {ba6163d9-04a1-4d29-b605-72e2ffb1dc7f} - Synthetic SCSI Controller
        Device_ID = {f8b3781a-1e82-4818-a1c3-63d806ec15bb}
        Sysfs path: /sys/bus/vmbus/devices/f8b3781a-1e82-4818-a1c3-63d806ec15bb
        Rel_ID=15, target_cpu=6
        Rel_ID=18, target_cpu=1

VMBUS ID 16: Class_ID = {ba6163d9-04a1-4d29-b605-72e2ffb1dc7f} - Synthetic SCSI Controller
        Device_ID = {f8b3781b-1e82-4818-a1c3-63d806ec15bb}
        Sysfs path: /sys/bus/vmbus/devices/f8b3781b-1e82-4818-a1c3-63d806ec15bb
        Rel_ID=16, target_cpu=7
        Rel_ID=17, target_cpu=0

VMBUS ID 47: Class_ID = {44c4f61d-4444-4400-9d52-802e27ede19f} - PCI Express pass-through
        Device_ID = {6041f3c4-38d5-407c-b56f-985d03d32ca3}
        Sysfs path: /sys/bus/vmbus/devices/6041f3c4-38d5-407c-b56f-985d03d32ca3
        Rel_ID=47, target_cpu=0

VMBUS ID 48: Class_ID = {44c4f61d-4444-4400-9d52-802e27ede19f} - PCI Express pass-through
        Device_ID = {64c70d9c-0b99-4bc0-ab63-83c1c785dfce}
        Sysfs path: /sys/bus/vmbus/devices/64c70d9c-0b99-4bc0-ab63-83c1c785dfce
        Rel_ID=48, target_cpu=0

VMBUS ID 49: Class_ID = {44c4f61d-4444-4400-9d52-802e27ede19f} - PCI Express pass-through
        Device_ID = {58878e11-a2a3-4ea4-97af-07fb5274e86b}
        Sysfs path: /sys/bus/vmbus/devices/58878e11-a2a3-4ea4-97af-07fb5274e86b
        Rel_ID=49, target_cpu=0

VMBUS ID 50: Class_ID = {44c4f61d-4444-4400-9d52-802e27ede19f} - PCI Express pass-through
        Device_ID = {f2d53aea-2f81-4315-9baf-613b49641633}
        Sysfs path: /sys/bus/vmbus/devices/f2d53aea-2f81-4315-9baf-613b49641633
        Rel_ID=50, target_cpu=0
```

## Ethernet interface names mapping

By taking the `Sysfs path` of the `Synthetic network adapter` lines from the `lsvmbus -vv`, we can lookup the Ethernet interface name assigned with it by looking in the `net` subfolder:

```bash
ls /sys/bus/vmbus/devices/000d3a03-19f7-000d-3a03-19f7000d3a03/net
eth3

ls /sys/bus/vmbus/devices/000d3a03-1eb1-000d-3a03-1eb1000d3a03/net
eth1
```

We can more easily see the mapping between Ethernet interface names (i.e., eth0, eth1, eth2, eth3) and the `Device_ID` above using `ls -la /sys/class/net`:

```text
azureuser@vmav0:~$ ls -la /sys/class/net

total 0
drwxr-xr-x  2 root root 0 Jan 31 22:51 .
drwxr-xr-x 67 root root 0 Jan 31 22:51 ..
lrwxrwxrwx  1 root root 0 Jan 31 22:51 enP12161s3 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/f2d53aea-2f81-4315-9baf-613b49641633/pci2f81:00/2f81:00:02.0/net/enP12161s3
lrwxrwxrwx  1 root root 0 Jan 31 22:51 enP14549s4 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/6041f3c4-38d5-407c-b56f-985d03d32ca3/pci38d5:00/38d5:00:02.0/net/enP14549s4
lrwxrwxrwx  1 root root 0 Jan 31 22:51 enP2969s1 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/64c70d9c-0b99-4bc0-ab63-83c1c785dfce/pci0b99:00/0b99:00:02.0/net/enP2969s1
lrwxrwxrwx  1 root root 0 Jan 31 22:51 enP41635s2 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/58878e11-a2a3-4ea4-97af-07fb5274e86b/pcia2a3:00/a2a3:00:02.0/net/enP41635s2
lrwxrwxrwx  1 root root 0 Jan 31 22:51 eth0 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-1646-000d-3a03-1646000d3a03/net/eth0
lrwxrwxrwx  1 root root 0 Jan 31 22:51 eth1 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-1eb1-000d-3a03-1eb1000d3a03/net/eth1
lrwxrwxrwx  1 root root 0 Jan 31 22:51 eth2 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-18c9-000d-3a03-18c9000d3a03/net/eth2
lrwxrwxrwx  1 root root 0 Jan 31 22:51 eth3 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-19f7-000d-3a03-19f7000d3a03/net/eth3
lrwxrwxrwx  1 root root 0 Jan 31 22:51 lo -> ../../devices/virtual/net/lo
```

## Different values after VM is deallocated and start

Since physical bus ids are going to change when VM moves to a different host (i.e., after deallocate and restart), the application should not use the bus id directly, but instead should use the Ethernet interface names like eth0, eth1, eth2, eth3 and can lookup the device ids and bus info if required.

After stopped the restarting the VM in Azure portal, we can see that the bus info and PCI device ids changed:

```bash
azureuser@vmav0:~$ lshw -c network -businfo
WARNING: you should run this program as super-user.
Bus info          Device      Class      Description
====================================================
pci@0ddb:00:02.0  enP3547s2   network    MT27800 Family [ConnectX-5 Virtual Function]
pci@90d4:00:02.0  enP37076s3  network    MT27800 Family [ConnectX-5 Virtual Function]
pci@91bc:00:02.0  enP37308s4  network    MT27800 Family [ConnectX-5 Virtual Function]
pci@d4af:00:02.0  enP54447s1  network    MT27800 Family [ConnectX-5 Virtual Function]
                  eth3        network    Ethernet interface
                  eth0        network    Ethernet interface
                  eth1        network    Ethernet interface
                  eth2        network    Ethernet interface
```

We also see that there maybe additional VMBUS IDs appearing and changing the `Synthetic network adapter` values:

```text
azureuser@vmav0:~$ lsvmbus

VMBUS ID  1: Unknown
VMBUS ID  2: [Dynamic Memory]
VMBUS ID  3: Synthetic IDE Controller
VMBUS ID  4: Synthetic IDE Controller
VMBUS ID  5: Synthetic mouse
VMBUS ID  6: Synthetic keyboard
VMBUS ID  7: Synthetic framebuffer adapter
VMBUS ID  8: [Heartbeat]
VMBUS ID  9: [Data Exchange]
VMBUS ID 10: [Operating system shutdown]
VMBUS ID 11: [Time Synchronization]
VMBUS ID 12: Synthetic network adapter
VMBUS ID 13: Synthetic network adapter
VMBUS ID 14: Synthetic network adapter
VMBUS ID 15: Synthetic network adapter
VMBUS ID 16: Synthetic SCSI Controller
VMBUS ID 17: Synthetic SCSI Controller
VMBUS ID 48: PCI Express pass-through
VMBUS ID 49: PCI Express pass-through
VMBUS ID 50: PCI Express pass-through
VMBUS ID 51: PCI Express pass-through
```

However, the mapping between Ethernet interface names (i.e., eth0, eth1, eth2, eth3) to physical device still allows us to properly identify each of the NICs:

```bash
azureuser@vmav0:~$ ls -la /sys/class/net

total 0
drwxr-xr-x  2 root root 0 Jan 31 23:31 .
drwxr-xr-x 67 root root 0 Jan 31 23:31 ..
lrwxrwxrwx  1 root root 0 Jan 31 23:32 enP3547s2 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/10e3b1d5-0ddb-46f0-8f22-80db187e4f9b/pci0ddb:00/0ddb:00:02.0/net/enP3547s2
lrwxrwxrwx  1 root root 0 Jan 31 23:32 enP37076s3 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/f751e13c-90d4-4375-a580-1e2268a3e164/pci90d4:00/90d4:00:02.0/net/enP37076s3
lrwxrwxrwx  1 root root 0 Jan 31 23:32 enP37308s4 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/beeff40c-91bc-4978-b463-a04c08bd089a/pci91bc:00/91bc:00:02.0/net/enP37308s4
lrwxrwxrwx  1 root root 0 Jan 31 23:32 enP54447s1 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/5999e2f9-d4af-4335-b534-2831b5c15238/pcid4af:00/d4af:00:02.0/net/enP54447s1
lrwxrwxrwx  1 root root 0 Jan 31 23:32 eth0 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-1646-000d-3a03-1646000d3a03/net/eth0
lrwxrwxrwx  1 root root 0 Jan 31 23:32 eth1 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-1eb1-000d-3a03-1eb1000d3a03/net/eth1
lrwxrwxrwx  1 root root 0 Jan 31 23:32 eth2 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-18c9-000d-3a03-18c9000d3a03/net/eth2
lrwxrwxrwx  1 root root 0 Jan 31 23:32 eth3 -> ../../devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A03:00/device:07/VMBUS:01/000d3a03-19f7-000d-3a03-19f7000d3a03/net/eth3
lrwxrwxrwx  1 root root 0 Jan 31 23:31 lo -> ../../devices/virtual/net/lo
```

## Delete resource group

After we finished experimenting, we can delete the deployed resource group:

```bash
az group delete --resource-group rg-multinic1
```
