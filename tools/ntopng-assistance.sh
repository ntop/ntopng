#!/bin/bash

#
# (C) 2018 - ntop.org
#
# This tool enables you to connect to your remote
# ntopng instance via n2n. Please refer to
# https://www.ntop.org/guides/ntopng/remote_assistance.html
# for more information
#

########################################

#
# IMPORTANT
# The values below should be correct for your setup. However
# feel free to change them if you need to adapt them to your setup
#
MY_IP="192.168.166.10"
CLIENT_IP="192.168.166.1"
N2N_IFACE="n2n0"
N2N_SUPERNODE="dns.ntop.org:7777"

########################################

N2N_BIN="`which edge 2>/dev/null`"

# Search it in the local n2n build (if any)
if [[ ! -x "$N2N_BIN" ]]; then
  N2N_BIN="`readlink -f ~/n2n/edge`"
fi

if [[ ! -x "$N2N_BIN" ]]; then
  echo "n2n binary not found" >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: `basename $0` key" >&2
  exit 1
fi

N2N_COMMUNITY="$1"
N2N_KEY="$1"

# Try to differentiate the IP
if which ip 2>/dev/null >/dev/null ; then
  CUR_IP=`ip route get 8.8.8.8 | head -n1 | awk '{print $7}'`
  LAST_PART="${CUR_IP##*.}"

  if [[ ( "$LAST_PART" -gt 2 ) && ( "$LAST_PART" -lt 254 ) ]]; then
    MY_IP="${MY_IP%.*}.${LAST_PART}"
  fi
fi

printf "********************************************\n"
printf "*** Client machine is at %-15s ***\n" ${CLIENT_IP}
printf "*** Your IP is %-15s           ***\n" ${MY_IP}
printf "********************************************\n"
sudo "$N2N_BIN" -d $N2N_IFACE -c $N2N_COMMUNITY -k $N2N_KEY -u `id -u` -g `id -g` -a $MY_IP -f -l $N2N_SUPERNODE
