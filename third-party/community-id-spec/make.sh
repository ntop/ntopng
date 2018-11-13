#! /bin/bash

for pcap in ./pcaps/*.pcap; do
    echo $pcap
    ./community-id.py $@ $pcap > $pcap.log
done
