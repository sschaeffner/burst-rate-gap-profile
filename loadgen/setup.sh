#!/bin/bash

# Script is run locally on experiment server.

# exit on error
set -e
# log every command
set -x

MOONGEN_REPO="https://github.com/emmericp/MoonGen.git"
MOONGEN_REPO_COMMIT="7746ff2f0afdbb222aa9cb220b48355e2d19552b"
MOONGEN_DIR="/root/moongen"

LOADGEN_EGRESS_IF="enp6s0f0"
LOADGEN_INGRESS_IF="enp6s0f1"
LOADGEN_EGRESS_IP="10.10.1.1"
LOADGEN_INGRESS_IP="10.10.2.1"

ip addr del $LOADGEN_INGRESS_IP/24  dev $LOADGEN_INGRESS_IF || true
ip addr del $LOADGEN_EGRESS_IP/24 dev $LOADGEN_EGRESS_IF || true

ip link set dev $LOADGEN_INGRESS_IF down
ip link set dev $LOADGEN_EGRESS_IF down

# apt update & upgrade
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages

apt-get install -y build-essential cmake libnuma-dev pciutils libtbb2
apt-get install -y linux-headers-$(uname -r)

# install moongen
git clone "$MOONGEN_REPO" "$MOONGEN_DIR" || true
cd "$MOONGEN_DIR"
git checkout "$MOONGEN_REPO_COMMIT"
git submodule update --init --recursive

"$MOONGEN_DIR"/build.sh
"$MOONGEN_DIR"/bind-interfaces.sh
"$MOONGEN_DIR"/setup-hugetlbfs.sh

echo "setup successful"
