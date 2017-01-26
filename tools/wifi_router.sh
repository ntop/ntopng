#!/bin/sh
#
# See
# ntopng/doc/README.raspberry
#

# Give WiFi an IP address
ifconfig wlan0 192.168.42.1 netmask 255.255.255.0

# Enable routing
echo 1 > /proc/sys/net/ipv4/ip_forward

# Enabling NAT
iptables -F
iptables -F -t nat
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Enable NFQUEUE
iptables -A FORWARD -i wlan0 -j NFQUEUE --queue-num 0
iptables -A FORWARD -i eth0  -j NFQUEUE --queue-num 0

# Enable forwarding
iptables -A FORWARD -i eth0  -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Check NAT
# iptables -t nat -S
# iptables -S

# Enable DHCPd
service isc-dhcp-server start

# Start ntopng
ntopng -i nf:0 -w 80,3000
