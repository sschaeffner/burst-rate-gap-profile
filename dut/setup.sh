#!/bin/bash

# Script is run locally on experiment server.

# exit on error
set -e
# log every command
set -x

DUT_INGRESS_IF="enp6s0f1"
DUT_EGRESS_IF="enp6s0f0"
DUT_INGRESS_PCI="0000:06:00.1"
DUT_EGRESS_PCI="0000:06:00.0"

# reset interfaces
ip link set dev $DUT_INGRESS_IF down
ip link set dev $DUT_EGRESS_IF down
ip addr flush dev $DUT_INGRESS_IF
ip addr flush dev $DUT_EGRESS_IF

# apt upgrade
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages

# build and install DPDK (https://docs.openvswitch.org/en/latest/intro/install/dpdk/)
apt-get install -y build-essential meson ninja-build python3-pyelftools libnuma-dev
wget https://fast.dpdk.org/rel/dpdk-21.11.1.tar.xz
tar xf dpdk-21.11.1.tar.xz
export DPDK_DIR=/root/dpdk-stable-21.11.1
cd $DPDK_DIR

export DPDK_BUILD=$DPDK_DIR/build
meson build
ninja -C build
ninja -C build install
ldconfig
pkg-config --modversion libdpdk

# build dpdk-kmods
export DPDK_KMODS_DIR=/root/dpdk-kmods
git clone git://dpdk.org/dpdk-kmods $DPDK_KMODS_DIR
cd $DPDK_KMODS_DIR/linux/igb_uio
make

# install Open vSwitch
apt-get install -y libcap-ng-dev uuid-dev libuuid1 autoconf automake libtool
export OVS_DIR=/root/ovs
git clone https://github.com/openvswitch/ovs.git $OVS_DIR
cd $OVS_DIR
./boot.sh
./configure --with-dpdk=static CFLAGS="-Ofast -msse4.2 -mpopcnt"
make
make install

# set "intel_iommu=on iommu=pt" in Linux kernel boot parameters
echo "GRUB_CMDLINE_LINUX=\"console=ttyS0,115200 intel_iommu=on iommu=pt\"" >> /etc/default/grub
update-grub

# setup systemd service for setup-2
echo "[Unit]
Description=setup part 2.

[Service]
Type=simple
ExecStart=/local/repository/dut/setup-2.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/setup2.service
systemctl enable setup2.service

echo "setup successful"
echo "rebooting to activate iommu configuration..."
shutdown -r now
