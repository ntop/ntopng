#!/bin/bash
#
# A script to setup a testing environment for nEdge based on linux namespaces.
# Namespaces make it possible to use a single machine to simulate devices
# on the same subnet.
#

function cleanup() {
  # Cleanup
  ip link set br0 down 2>/dev/null
  brctl delbr br0 2>/dev/null
  ip -all netns delete
  iptables -D FORWARD -m physdev --physdev-is-bridged -j ACCEPT 2>/dev/null
  iptables -t nat -D POSTROUTING -s 172.16.100.0/24 -j MASQUERADE 2>/dev/null
  iptables -t nat -D POSTROUTING -s 172.16.1.0/24 -j MASQUERADE 2>/dev/null
  #ip netns | xargs -I {} sudo ip netns delete {}
}

function enable_forwarding() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  modprobe br_netfilter
  echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
}

#
# Network setup
#   br0: connects the "lan" and "wan" interfaces of the host
#   lan: it's a veth, connected to the clins namespace
#   wan: it's a veth, connected to the srvns namespace
#   inetif: it's a veth, connects the srvns to internet
#
# Path of "ip netns exec clins ping 8.8.8.8":
#   1. ICMP request is generated on clins, follows the default route via 172.16.1.1
#   2. The packet goes out of the lan interface and reaches br0
#   3. The bridge switches the packet to the wan interface
#   4. The packet reaches 172.16.1.1 in srvns (on interface srvif)
#   5. The packet follows the default route via 172.16.100.1 and it's masqueraded
#   6. The packet reaches the host again on inetif
#   7. Host routes the packet as normal
#
function setup_bridge_mode() {
  # Namespaces
  ip netns add clins
  ip netns add srvns
  sleep 1

  # WAN
  #   srvif (srvns) <-> (main) wan
  ip link add srvif type veth peer name wan
  ip link set srvif netns srvns
  ip netns exec srvns ifconfig srvif 172.16.1.1/24 up
  ip netns exec srvns ifconfig lo up
  ifconfig wan up

  # Internet (connect to the server interface)
  ip link add srvinet type veth peer name inetif
  ip link set srvinet netns srvns
  ip netns exec srvns ifconfig srvinet 172.16.100.2/24 up
  ip netns exec srvns ip route add default via 172.16.100.1
  ip netns exec srvns iptables -t nat -o srvinet -A POSTROUTING -j MASQUERADE
  ifconfig inetif 172.16.100.1 up

  # LAN
  #   (main) lan <-> cliif (clins)
  ip link add cliif type veth peer name lan
  ip link set cliif netns clins
  ip netns exec clins ifconfig cliif 172.16.1.11/24 up
  ip netns exec clins ip route add default via 172.16.1.1
  ip netns exec clins ifconfig lo up
  ifconfig lan up

  # Bridge
  # wan <-br0-> lan
  brctl addbr br0
  brctl addif br0 lan
  brctl addif br0 wan
  ip link set br0 up

  iptables -t nat -A POSTROUTING -s 172.16.100.0/24 -j MASQUERADE

  # Print configuration
  echo "[LAN (host)]"
  ifconfig lan | head -n -1
  echo "[LAN (clins)]"
  ip netns exec clins ifconfig cliif | head -n -1
  echo -en "\t"
  ip netns exec clins ip route show default

  echo -e "\n[WAN (host)]"
  ifconfig wan | head -n -1
  echo "[WAN (srvns)]"
  ip netns exec srvns ifconfig srvif | head -n -1
  echo -en "\t"
  ip netns exec srvns ip route show default

  #echo -e "\n[Internet (host)]"
  #ifconfig inetif | head -n -1
  #echo "[Internet (srvns)]"
  #ip netns exec srvns ifconfig srvinet | head -n -1

  # Test
  ip netns exec clins ping -c1 8.8.8.8
}

function setup_router_mode() {
  # Namespaces
  ip netns add clins
  sleep 1

  # LAN
  #   (main) lan <-> cliif (clins)
  ip link add cliif type veth peer name lan
  ip link set cliif netns clins
  ip netns exec clins ifconfig cliif 172.16.1.11/24 up
  ip netns exec clins ip route add default via 172.16.1.1
  ip netns exec clins ifconfig lo up
  ifconfig lan 172.16.1.1 up

  # NOTE: the WAN interface is the host actual internet interface

  iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -j MASQUERADE

  echo "[LAN (host)]"
  ifconfig lan | head -n -1
  echo "[LAN (clins)]"
  ip netns exec clins ifconfig cliif | head -n -1
  echo -en "\t"
  ip netns exec clins ip route show default

  # Test
  ip netns exec clins ping -c1 8.8.8.8
}

if [[ $UID -ne 0 ]]; then
  echo "Not root" >&2
  exit 1
fi

MODE="$1"

if [[ ( $MODE != "bridge" ) && ( $MODE != "router" ) && ( $MODE != "cleanup" ) ]]; then
  cat <<EOF
Usage: `basename $0` [bridge|router|cleanup]

  bridge        Setup br0 to bridge virtual lan and wan interfaces
  router        Setup a virtual lan interface for routing
  cleanup       Cleanup the existing rules (automatically done by bridge/router)
EOF
  exit 1
fi

case "$1" in
cleanup)
  cleanup
  ;;
bridge)
  cleanup
  enable_forwarding
  setup_bridge_mode
  ;;
router)
  cleanup
  enable_forwarding
  setup_router_mode
  ;;
esac
