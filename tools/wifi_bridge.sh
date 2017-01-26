#!/bin/sh

# Setup the bridge
brctl addbr br0
brctl addif br0 eth0 wlan0

# Enable the iptables
iptables -F
iptables -A FORWARD -m physdev --physdev-in  wlan0 -j NFQUEUE --queue-num 0

# Now start ntopng in bridging mode on netfilter
# ntopng -i nf:0 -w 80,3000
