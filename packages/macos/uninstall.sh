#!/bin/sh

NUM=1
echo "$NUM. Uninstall ntopng"
sudo /bin/rm -f /usr/local/bin/ntopng
sudo /bin/rm -f /usr/local/bin/ntopng-bin
sudo launchctl unload /Library/LaunchDaemons/org.ntop.ntopng.plist

NUM=$((NUM+1))
echo "$NUM. Uninstall companion files"
sudo /bin/rm -rf /usr/local/share/ntopng/
sudo /bin/rm -f /usr/local/share/man/man8/ntopng.8

NUM=$((NUM+1))
echo "$NUM. Uninstall config file"
sudo /bin/rm -f /usr/local/etc/ntopng.conf

NUM=$((NUM+1))
echo "$NUM. Uninstall startup file"
sudo launchctl unload /Library/LaunchDaemons/org.ntop.ntopng.plist
sudo /bin/rm -f /Library/LaunchDaemons/org.ntop.ntopng.plist

if [ -f "/Library/LaunchDaemons/io.redis.redis-server.plist" ]; then
    sudo launchctl unload /Library/LaunchDaemons/io.redis.redis-server.plist
    sudo /bin/rm -f /Library/LaunchDaemons/io.redis.redis-server.plist
    sudo /bin/rm -f /usr/local/etc/ntopng/ntopng.conf
fi

NUM=$((NUM+1))
echo "$NUM. Deleting package information"
sudo /usr/sbin/pkgutil --forget org.ntop.pkg.ntopng > /dev/null

echo "Done"
