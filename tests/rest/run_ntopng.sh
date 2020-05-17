#!/bin/sh

pkill ntopng || true
sleep 5
cd ../../; ./ntopng -i tests/rest/pcap/test.pcap -l 0
