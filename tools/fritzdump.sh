#!/bin/bash

# The is the address of the router
FRITZIP=http://192.168.2.1
FRITZPWD=$1
# This is the WAN interface
#IFACE="2-0"

# Lan Interface
IFACE="1-lan"

FRITZUSER=""
SIDFILE="/tmp/fritz.sid"


if [ ! -f $SIDFILE ]; then
  touch $SIDFILE
fi

SID=$(cat $SIDFILE)

CHALLENGE=$(curl -k -s $FRITZIP/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
HASH=$(perl -MPOSIX -e '
    use Digest::MD5 "md5_hex";
    my $ch_Pw = "$ARGV[0]-$ARGV[1]";
    $ch_Pw =~ s/(.)/$1 . chr(0)/eg; 
    my $md5 = lc(md5_hex($ch_Pw)); 
    print $md5;
  ' -- "$CHALLENGE" "$FRITZPWD")
  curl -k -s "$FRITZIP/login_sid.lua" -d "response=$CHALLENGE-$HASH" -d 'username='${FRITZUSER} | grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2 > $SIDFILE

SID=$(cat $SIDFILE)

echo "Capturing traffic.." 1>&2 

# In case you want to use tshark instead of ntopng
#wget --no-check-certificate -qO- $FRITZIP/cgi-bin/capture_notimeout?ifaceorminor=$IFACE\&snaplen=\&capture=Start\&sid=$SID | /usr/local/bin/tshark -r -

wget --no-check-certificate -qO- $FRITZIP/cgi-bin/capture_notimeout?ifaceorminor=$IFACE\&snaplen=\&capture=Start\&sid=$SID | ntopng -i -

