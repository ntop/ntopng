#!/bin/bash

# Wait for redis daemon to start accepting connections.
while ! $SNAP/bin/netcat -z localhost 6379; do sleep 0.1; done

# Get the network interfaces for ntopng to collect.
nics=(/sys/class/net/*)

# Start ntopng on the correct interfaces.
$SNAP/bin/ntopng -d "$SNAP_COMMON" -t "$SNAP/share/ntopng" -1 "$SNAP/share/ntopng/httpdocs" -2 "$SNAP/share/ntopng/scripts" -3 "$SNAP/share/ntopng/scripts/callbacks" -s "${nics[@]//\/sys\/class\/net\//-i}"

