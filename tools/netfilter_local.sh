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

modprobe nf_conntrack_ipv4
echo 1 > /proc/sys/net/netfilter/nf_conntrack_acct
nfacct flush
nfacct add ipv4

iptables -F
iptables -F -t mangle

iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -A INPUT -i $IFNAME -m mark --mark 0 -j NFQUEUE --queue-num 0 --queue-bypass
iptables -A OUTPUT -o $IFNAME -m mark --mark 0 -j NFQUEUE --queue-num 0 --queue-bypass
iptables -t mangle -A POSTROUTING -j CONNMARK --save-mark
