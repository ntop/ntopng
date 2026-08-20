#!/bin/sh

FRESH_INSTALL=0
DATA_DIR=/var/lib/ntopng/
if [ ! -d "$DATA_DIR" ]; then
    FRESH_INSTALL=1

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

if [ "$FRESH_INSTALL" -eq "1" ]; then
    # Force ZMQ encryption on frash installations (avoid breaking old configurations)
    if hash redis-cli 2>/dev/null; then
	redis-cli set "ntopng.prefs.zmq.force_encryption" "1" >/dev/null 2>&1 || true
    fi
fi

# Enable + start ntopng
sudo launchctl load -w /Library/LaunchDaemons/org.ntop.ntopng.plist
