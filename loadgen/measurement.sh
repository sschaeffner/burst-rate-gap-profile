#!/bin/bash

# Script is run locally on experiment server.

# exit on error
set -e
# log every command
set -x

MOONGEN_DIR="/root/moongen"
REPO_DIR="/local/repository"

LOADGEN_WARM_UP=0
LOADGEN_ENABLE_IP_SW_CHKSUM_CALC=1
LOADGEN_ENABLE_OFFLOAD=0

PKT_SZ=64
PKT_RATE=1500000
BURST_SZ=128

LOADGEN_EGRESS_DEV=1
LOADGEN_INGRESS_DEV=2
LOADGEN_EGRESS_MAC="0c:42:a1:e2:a7:90"
LOADGEN_INGRESS_MAC="0c:42:a1:e2:a7:91"
LOADGEN_EGRESS_IP="10.10.1.1"
LOADGEN_INGRESS_IP="10.10.2.1"

DUT_INGRESS_MAC="0c:42:a1:dd:5b:94"
DUT_EGRESS_MAC="0c:42:a1:dd:5b:95"
DUT_INGRESS_IP="10.10.1.2"
DUT_EGRESS_IP="10.10.2.2"

PKTS_TOTAL=$(($PKT_RATE*60))

echo "send packets with size: $PKT_SZ, rate: $PKT_RATE, and burst size: $BURST_SZ."

until ! killall "MoonGen"; do echo "k"; sleep 1; done

# sleep 10

$MOONGEN_DIR/build/MoonGen $REPO_DIR/loadgen/soft-gen.lua --src-mac $LOADGEN_EGRESS_MAC --dst-mac $DUT_INGRESS_MAC --src-ip $LOADGEN_EGRESS_IP --dst-ip $LOADGEN_INGRESS_IP --fix-packetrate $PKT_RATE --size $PKT_SZ --burst $BURST_SZ --packets $PKTS_TOTAL --chksum-offload $LOADGEN_ENABLE_OFFLOAD --ip-chksum $LOADGEN_ENABLE_IP_SW_CHKSUM_CALC --warm-up $LOADGEN_WARM_UP $LOADGEN_EGRESS_DEV $LOADGEN_INGRESS_DEV # > /root/throughput.log

# sleep 50

until ! killall "MoonGen"; do echo "k"; sleep 1; done

# sleep 5

echo "experiment successful"
