#!/bin/sh

echo "[1/4] Uninstall ntopng"
sudo /bin/rm -f /usr/local/bin/ntopng

echo "[2/4] Uninstall companion files"
sudo /bin/rm -rf /usr/local/share/ntopng/
sudo /bin/rm -f /usr/local/share/man/man8/ntopng.8

echo "[3/4] Uninstall config file"
sudo /bin/rm -f /usr/local/etc/ntopng.conf

echo "[4/4] Uninstall startup file"
sudo /bin/rm -f /Library/LaunchDaemons/org.ntop.ntopng.plist

echo "Done"
