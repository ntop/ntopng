#!/bin/sh

# Create data directory
mkdir /var/lib/ntopng/
chmod gou+w /var/lib/ntopng/

# Enable + start redis
sudo launchctl load -w /Library/LaunchDaemons/io.redis.redis-server.plist

# Enable + start ntopng
sudo launchctl enable /Library/LaunchDaemons/org.ntop.ntopng.plist
sudo launchctl load   /Library/LaunchDaemons/org.ntop.ntopng.plist
