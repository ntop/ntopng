#!/bin/sh

cat <<EOF >"$SNAP_DATA/redis.conf"
bind 127.0.0.1
EOF

$SNAP/bin/redis-server "$SNAP_DATA/redis.conf"
