#!/bin/bash

cd /root

# Install OFED drivers
wget http://content.mellanox.com/ofed/MLNX_OFED-5.6-1.0.3.3/MLNX_OFED_LINUX-5.6-1.0.3.3-ubuntu18.04-x86_64.tgz
tar xf MLNX_OFED_LINUX-5.6-1.0.3.3-ubuntu18.04-x86_64.tgz
cd MLNX_OFED_LINUX-5.6-1.0.3.3-ubuntu18.04-x86_64
# sudo ./mlnxofedinstall --without-fw-update --add-kernel-support --force

# Restart drivers
# sudo /etc/init.d/openibd restart

# Download software on each VM

# Install software on each VM

sudo apt-get update
sudo apt-get install -y dstat iperf3 fio
