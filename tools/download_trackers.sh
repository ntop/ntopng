#!/bin/bash

# Gianluca Cerotto <g.cerotto@autistici.org>

EASY=$(wget -O - https://easylist.to/easylist/easylist.txt https://easylist.to/easylist/easyprivacy.txt | grep -v '/'| grep -o -P '(?<=\|\|).*(?=(\^$|\^\$third-party$))')
DISCONNECT=$(wget -O - https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt | awk 'NR  > 4 {print}')
PGL=$(wget -O - https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&mimetype=plaintext)
NOTRACK=$(wget -O - https://raw.githubusercontent.com/quidsup/notrack/master/trackers.txt | awk 'NR  > 2 {print $1}')

echo $EASY$DISCONNECT$PGL$NOTRACK |  tr ' ' '\n' | sort -u > $1

