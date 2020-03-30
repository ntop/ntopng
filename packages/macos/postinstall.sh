#!/bin/sh

DATA_DIR=/var/lib/ntopng/
if [ ! -d "$DATA_DIR" ]; then
    # Create data directory
    mkdir $DATA_DIR
    chmod gou+w $DATA_DIR
fi

# Enable + start redis
NUM_REDIS_PROCESES=`ps auxw | grep redis-server | grep -v grep | wc -l`
if [ "$NUM_REDIS_PROCESES" -eq "0" ]; then
    ps auxw | grep redis-server|grep -v grep | wc -lx2
    sudo launchctl load -w /Library/LaunchDaemons/io.redis.redis-server.plist
fi

# Enable + start ntopng
sudo launchctl enable /Library/LaunchDaemons/org.ntop.ntopng.plist
sudo launchctl load   /Library/LaunchDaemons/org.ntop.ntopng.plist
