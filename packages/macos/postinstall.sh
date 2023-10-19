#!/bin/sh

DATA_DIR=/var/lib/ntopng/
if [ ! -d "$DATA_DIR" ]; then
    # Create data directory
    mkdir $DATA_DIR
    chmod gou+w $DATA_DIR
fi

# Enable + start redis
NUM_REDIS_PROCESES=`ps auxw | grep ntopng-redis-server | grep -v grep | wc -l`
if [ "$NUM_REDIS_PROCESES" -eq "0" ]; then
    ps auxw | grep ntopng-redis-server|grep -v grep | wc -lx2
    #
    # Enable debug as follows
    #
    # sudo log config --mode "level:debug" --subsystem io.redis.redis-server
    # tail -f /var/log/system.log
    #
    sudo launchctl load -w /Library/LaunchDaemons/io.redis.redis-server.plist
fi

# Enable + start ntopng
sudo launchctl load -w /Library/LaunchDaemons/org.ntop.ntopng.plist
