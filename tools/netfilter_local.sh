#!/bin/bash
#
# Basic netfilter initialization for local interface
#

if [[ $UID -ne 0 ]]; then
  echo "Not root" >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: `basename $0` local_interface" >&2
  exit 1
fi

IFNAME="$1"

iptables -A INPUT -i $IFNAME -j NFQUEUE --queue-num 0 --queue-bypass
iptables -A OUTPUT -o $IFNAME -j NFQUEUE --queue-num 0 --queue-bypass
