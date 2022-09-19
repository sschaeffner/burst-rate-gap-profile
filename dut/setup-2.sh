#!/bin/bash

# exit on error
set -e
# log every command
set -x

DUT_INGRESS_IF="enp6s0f1"
DUT_EGRESS_IF="enp6s0f0"
DUT_INGRESS_PCI="0000:06:00.1"
DUT_EGRESS_PCI="0000:06:00.0"

DPDK_DIR=/root/dpdk-stable-21.11.1
DPDK_KMODS_DIR=/root/dpdk-kmods

# setup
sysctl -w vm.nr_hugepages=2048
mount -t hugetlbfs none /dev/hugepages

# run Open vSwitch
export PATH=$PATH:/usr/local/share/openvswitch/scripts
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock
ovs-ctl --no-ovs-vswitchd --system-id=b31ad044-277a-11ed-a261-0242ac120002 start
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="--iova-mode=pa"
ovs-ctl --no-ovsdb-server --db-sock="$DB_SOCK" start

# validate
ovs-vsctl get Open_vSwitch . dpdk_initialized
ovs-vswitchd --version

# bind devices
modprobe uio
insmod $DPDK_KMODS_DIR/linux/igb_uio/igb_uio.ko

$DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio $DUT_INGRESS_PCI
$DPDK_DIR/usertools/dpdk-devbind.py --bind=igb_uio $DUT_EGRESS_PCI
$DPDK_DIR/usertools/dpdk-devbind.py --status

# create bridge
ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl add-port br0 myportnameone -- set Interface myportnameone type=dpdk options:dpdk-devargs=$DUT_INGRESS_PCI
ovs-vsctl add-port br0 myportnametwo -- set Interface myportnametwo type=dpdk options:dpdk-devargs=$DUT_EGRESS_PCI

# no longer log every command
set +x

# keep alive
while [ 1 ]; do sleep 1; done