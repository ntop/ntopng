#!/bin/sh

NTOPNG_TEST_DATADIR="/var/lib/ntopng_test"
NTOPNG_TEST_REDIS="2"

# Make sure no other process is running
killall -9 ntopng || true
# sleep 5

# Cleanup old test stuff
redis-cli -n "${NTOPNG_TEST_REDIS}" "flushdb"
rm -rf "${NTOPNG_TEST_DATADIR}"

# Start the test
cd ../../; ./ntopng -d "${NTOPNG_TEST_DATADIR}" -r "@${NTOPNG_TEST_REDIS}" -N "ntopng_test" -i tests/rest/pcap/test.pcap --disable-login 1
